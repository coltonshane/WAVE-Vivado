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
#include "hdmi.h"
#include "usb.h"
#include "pcie.h"
#include "nvme.h"
#include "fs.h"
#include "frame.h"
#include "encoder.h"

#include "xscugic.h"
#include "xil_cache.h"

#define INTC_DEVICE_ID XPAR_SCUGIC_0_DEVICE_ID

void isrFOT(void * CallbackRef);
void isrVSYNC(void * CallbackRef);

XScuGic Gic;

u32 triggerShutdown = 0;
u32 requestFrames = 0;
u32 updateCMVRegs = 0;
u32 formatFileSystem = 0;
u32 closeFileSystem = 0;

int main()
{
	XScuGic_Config *gicConfig;
	u32 nvmeStatus;
	char strResult[128];

    init_platform();
    Xil_DCacheDisable();

    // Configure peripherals.
    gpioInit();
    supervisorInit();
    xil_printf("WAVE HELLO!\r\n");
    cmvInit();
    encoderInit();
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
    Xil_ExceptionEnable();

    // Configure and enable FOT interrupt (Highest Priority: 0).
    XScuGic_Connect(&Gic, 124, (Xil_ExceptionHandler) isrFOT, (void *) &Gic);
    XScuGic_SetPriorityTriggerType(&Gic, 124, 0x00, 0x03);
    XScuGic_Enable(&Gic, 124);

    // Configure and enable VSYNC interrupt (Second Highest Priority: 8).
    // NOTE: By default, XScuGic DOES NOT support nested interrupts.
    XScuGic_Connect(&Gic, 125, (Xil_ExceptionHandler) isrVSYNC, (void *) &Gic);
    XScuGic_SetPriorityTriggerType(&Gic, 125, 0x08, 0x03);
    XScuGic_Enable(&Gic, 125);

    usleep(1000);

    hdmiInit();
    usbInit();

    // Main loop.
    while(!triggerShutdown)
    {
    	usbPoll();
    	// frameService();

    	while(requestFrames)
    	{
    		// Toggle the frame request pin.
    		XGpioPs_WritePin(&Gpio, FRAME_REQ_PIN, 1);
    		usleep(1);
    		XGpioPs_WritePin(&Gpio, FRAME_REQ_PIN, 0);
    		requestFrames = 0;
    	}

    	if(updateCMVRegs)
    	{
    		updateCMVRegs = 0;
    	    cmvUpdateSettings();
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

