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
#include "usb.h"
#include "encoder.h"

#include "xscugic.h"

#define INTC_DEVICE_ID XPAR_SCUGIC_0_DEVICE_ID

void isrFOT(void * CallbackRef);

XScuGic Gic;

u32 triggerShutdown = 0;
u32 requestFrames = 0;
u32 updateCMVRegs = 0;

int main()
{
	XScuGic_Config *gicConfig;

    init_platform();
    print("Hello World\n\r");

    // Configure peripherals.
    gpioInit();
    supervisorInit();
    cmvInit();
    encoderInit();
    usbInit();

    // Configure and enable FOT interrupt.
    gicConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
    XScuGic_CfgInitialize(&Gic, gicConfig, gicConfig->CpuBaseAddress);
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, &Gic);
    Xil_ExceptionEnable();
    XScuGic_Connect(&Gic, 124, (Xil_ExceptionHandler) isrFOT, (void *) &Gic);
    XScuGic_Enable(&Gic, 124);

    usleep(1000);

    // Main loop.
    while(!triggerShutdown)
    {
    	usbPoll();
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
    }

    cleanup_platform();
    return 0;
}

