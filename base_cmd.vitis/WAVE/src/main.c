/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

#include "main.h"
#include "gpio.h"
#include "supervisor.h"
#include "cmv12000.h"
#include "wavelet.h"
#include "encoder.h"
#include "hdmi.h"
#include "ui.h"
#include "usb.h"
#include "pcie.h"
#include "nvme.h"
#include "fs.h"
#include "frame.h"
#include "camera_state.h"

#include "xscugic.h"
#include "xil_cache.h"

#define INTC_DEVICE_ID XPAR_SCUGIC_0_DEVICE_ID

void isrFOT(void * CallbackRef);
void isrVSYNC(void * CallbackRef);

u16 * psTemp = (u16 *)((u64) 0xFFA50800);
u16 * plTemp = (u16 *)((u64) 0xFFA50C00);

XScuGic Gic;

u32 triggerRecordStartStop = 0;
u32 recording = 0;
u32 triggerShutdown = 0;
u32 cmvServiceFlag = 0;
u32 formatFileSystem = 1;
u32 closeFileSystem = 0;

int main()
{
	XScuGic_Config *gicConfig;
	u32 nvmeStatus;
	char strResult[128];

    init_platform();
    Xil_DCacheDisable();

    // QSPI Flash Setup
    *(u32 *)((u64) 0xFF0F0014) = 0x00000000;	// Disable LQSPI.
    *(u32 *)((u64) 0xFF0F0114) = 0x00000000;	// Disable GQSPI.
    *(u32 *)((u64) 0xFF0F0000) = 0x800000C1;	// Master Mode.
    *(u32 *)((u64) 0xFF0F00A0) = 0x880002EC;	// LQSPI_CFG (TRM Table 24-6).
    *(u32 *)((u64) 0xFF0F00C0) = 0x00001A28;	// COMMAND (TRM Table 24-6).
    *(u32 *)((u64) 0xFF0F00C8) = 0x00000001;	// DUMMY_CYCLE_EN.
    *(u32 *)((u64) 0xFF0F0014) = 0x00000001;	// Enable LQSPI.

    // Configure peripherals.
    gpioInit();
    supervisorInit();
    xil_printf("WAVE HELLO!\r\n");
    waveletInit();
    encoderInit();
    cmvInit();
    pcieInit();

    // NVMe initialize and status check.
    nvmeStatus = nvmeInit();
    if (nvmeStatus == NVME_OK)
    {
    	xil_printf("NVMe initialization successful. PCIe link is Gen3 x4.\r\n");
    }
    else
    {
    	sprintf(strResult, "NVMe driver failed to initialize. Error Code: %8x\r\n", nvmeStatus);
    	xil_printf(strResult);
    	if(nvmeStatus == NVME_ERROR_PHY)
    	{
    		xil_printf("PCIe link must be Gen3 x4.\r\n");
    	}
    }

    usleep(1000);

    // Global interrupt controller setup and enable.
    gicConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
    XScuGic_CfgInitialize(&Gic, gicConfig, gicConfig->CpuBaseAddress);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, &Gic);

    // NOTE: By default, XScuGic DOES NOT support nested interrupts.

    // Configure and enable FOT interrupt (Highest Priority: 0x00).
    XScuGic_Connect(&Gic, 124, (Xil_ExceptionHandler) isrFOT, (void *) &Gic);
    XScuGic_SetPriorityTriggerType(&Gic, 124, 0x00, 0x03);
    XScuGic_Enable(&Gic, 124);

    // Configure and enable VSYNC interrupt (Second Highest Priority: 0x08).
    XScuGic_Connect(&Gic, 125, (Xil_ExceptionHandler) isrVSYNC, (void *) &Gic);
    XScuGic_SetPriorityTriggerType(&Gic, 125, 0x08, 0x03);
    XScuGic_Enable(&Gic, 125);

    // Configure and enable the UI interrupt (Third Highest Priority: 0x10).
    XScuGic_Connect(&Gic, 48, (Xil_ExceptionHandler)XGpioPs_IntrHandler, (void *) &Gpio);
    XScuGic_SetPriorityTriggerType(&Gic, 48, 0x10, 0x03);
    XScuGic_Enable(&Gic, 48);

    Xil_ExceptionEnable();

    usleep(1000);

    hdmiInit();
    usbInit();
    frameInit();
    cameraStateInit();
    uiInit();

    // Main loop.
    while(!triggerShutdown)
    {
    	usbPoll();

    	if(triggerRecordStartStop)
    	{
    		triggerRecordStartStop = 0;
    		recording = 1 - recording;
    		if(recording)
    		{ frameService(FRAME_REC_STATE_START); }
    	}
    	else if(recording)
    	{
    		frameService(FRAME_REC_STATE_CONTINUE);
    	}

    	if(cmvServiceFlag)
    	{
    		cmvServiceFlag = 0;
    		cmvService();
    		uiService();
    	}

    	if(formatFileSystem)
    	{
    		formatFileSystem = 0;
    		fsFormat();
    		fsCreateClip();
    	}

    	if(closeFileSystem)
    	{
    		closeFileSystem = 0;
    		fsDeinit();
    	}
    }

    fsDeinit();
    cleanup_platform();
    return 0;
}

float psplGetTemp(u16 * psplTemp)
{
	// TO-DO: Move to calibration.
	static float psDN0 = 0.0f;
	static float psT0 = -280.2f;
	static float psTSlope = 7.772E-3f;

	static float psTf = -100.0f;

	float psT = (*psplTemp - psDN0) * psTSlope + psT0;
	if(psTf == -100.0f)
	{
		psTf = psT;
	}
	else
	{
		psTf = 0.95f * psTf + 0.05f * psT;
	}

	return psTf;
}
