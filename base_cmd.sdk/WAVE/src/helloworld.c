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

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "sleep.h"

#include "xparameters.h"
#include "xgpiops.h"
#include "xuartps.h"
#include "xspips.h"

#include "cmv12000.h"

#define GPIO_DEVICE_ID XPAR_XGPIOPS_0_DEVICE_ID
#define GPIO1_PIN 78		// Bank 3, Pin 0, EMIO 0
#define GPIO2_PIN 79		// Bank 3, Pin 1, EMIO 1
#define GPIO3_PIN 80		// Bank 3, Pin 2, EMIO 2
#define GPIO4_PIN 81		// Bank 3, Pin 3, EMIO 3
#define LVDS_CLK_EN_PIN 82	// Bank 3, Pin 4, EMIO 4
#define PX_IN_RST_PIN 83	// Bank 3, Pin 5, EMIO 5
// Unused 84				// Bank 3, Pin 6, EMIO 6
// Unused 85				// Bank 3, Pin 7, EMIO 7
#define CMV_NRST_PIN 86		// Bank 3, Pin 8, EMIO 8
#define FRAME_REQ_PIN 87	// Bank 3, Pin 9, EMIO 9
#define T_EXP1_PIN 88		// Bank 3, Pin 10, EMIO 10
#define T_EXP2_PIN 89		// Bank 3, Pin 11, EMIO 11

#define UART0_DEVICE_ID XPAR_XUARTPS_0_DEVICE_ID

#define UART1_DEVICE_ID XPAR_XUARTPS_1_DEVICE_ID
#define UART1_PREFIX_MASK 0xF0
#define UART1_PREFIX_COMMAND 0xC0
#define UART1_PREFIX_REPLY 0xA0
#define UART1_COMMAND_EN_3V3SSD 0x01
#define UART1_COMMAND_EN_CMV 0x02
#define UART1_REPLY_ENPG_CMV 0x0E

#define SPI0_DEVICE_ID XPAR_XSPIPS_0_DEVICE_ID

XGpioPs Gpio;
XUartPs Uart0;
XUartPs Uart1;
XSpiPs Spi0;

u32 triggerShutdown = 0;
u32 requestFrame = 0;
u32 updateCMVRegs = 0;
u16 cmv_Exp_time = 1536;
u16 cmv_Exp_kp1 = 0;
u16 cmv_Exp_kp2 = 0;
u16 cmv_Vtfl = 64 * 128 + 64;
u16 cmv_Number_slopes = 1;

u32 * debug_core_addr  = (u32 *)(0xA0001004);
u32 * debug_core_dataL = (u32 *)(0xA0001008);
u32 * debug_core_dataH = (u32 *)(0xA000100C);

int main()
{
	XGpioPs_Config *gpioConfig;
	XUartPs_Config *uart0Config;
	XUartPs_Config *uart1Config;
	XSpiPs_Config *spi0Config;
	u8 uart1Reply = 0x00;
	u8 cmvPowerReady = 0x00;

    init_platform();
    print("Hello World\n\r");

    gpioConfig = XGpioPs_LookupConfig(GPIO_DEVICE_ID);
    XGpioPs_CfgInitialize(&Gpio, gpioConfig, gpioConfig->BaseAddr);

    uart0Config = XUartPs_LookupConfig(UART0_DEVICE_ID);
    XUartPs_CfgInitialize(&Uart0, uart0Config, uart0Config->BaseAddress);
    XUartPs_SetBaudRate(&Uart0, 115200);

    uart1Config = XUartPs_LookupConfig(UART1_DEVICE_ID);
    XUartPs_CfgInitialize(&Uart1, uart1Config, uart1Config->BaseAddress);
    XUartPs_SetBaudRate(&Uart1, 115200);

    spi0Config = XSpiPs_LookupConfig(SPI0_DEVICE_ID);
    XSpiPs_CfgInitialize(&Spi0, spi0Config, spi0Config->BaseAddress);
    XSpiPs_SetOptions(&Spi0, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION);
    XSpiPs_SetClkPrescaler(&Spi0, XSPIPS_CLK_PRESCALE_64);
    XSpiPs_SetSlaveSelect(&Spi0, 0x0F);

    // Set all EMIO GPIO to output low.
    for(u32 i = GPIO1_PIN; i <= T_EXP2_PIN; i++)
    {
    	XGpioPs_SetDirectionPin(&Gpio, i, 1);
    	XGpioPs_SetOutputEnablePin(&Gpio, i, 1);
    	XGpioPs_WritePin(&Gpio, i, 0);
    }

    // Hold the pixel input blocks in reset until the LVDS clock is available.
    XGpioPs_WritePin(&Gpio, PX_IN_RST_PIN, 1);

    // Tell the supervisor to enable the CMV12000 power supplies. Wait for power good signals.
    while(!cmvPowerReady)
    {
    	XUartPs_SendByte(uart1Config->BaseAddress, UART1_PREFIX_COMMAND | UART1_COMMAND_EN_CMV);
    	usleep(10000);
    	uart1Reply = XUartPs_RecvByte(uart1Config->BaseAddress);
    	if((uart1Reply & UART1_PREFIX_MASK) == UART1_PREFIX_REPLY)
    	{
    		// Reply prefix is valid, check EN and PG flags.
    		if((uart1Reply & UART1_REPLY_ENPG_CMV) == UART1_REPLY_ENPG_CMV)
    		{
    			// EN_CMV, PG_3V9, and PG_VDD18 are all set. Okay to proceed.
    			cmvPowerReady = 0x01;
    		}
    	}
    }
    usleep(1000);

    // Start the 600MHz LVDS clock.
    XGpioPs_WritePin(&Gpio, LVDS_CLK_EN_PIN, 1);
    usleep(10);

    // Take the CMV12000 out of reset.
    XGpioPs_WritePin(&Gpio, CMV_NRST_PIN, 1);
    usleep(10);

    // Take the pixel input blocks out of reset.
    XGpioPs_WritePin(&Gpio, PX_IN_RST_PIN, 0);
    usleep(1000);

    // Run link training on the CMV12000.
    cmvLinkTrain();

    usleep(1000);

    cmvRegInit(&Spi0);
    cmvRegSetMode(&Spi0);
    cmvRegWrite(&Spi0, CMV_REG_ADDR_TEST_PATTERN, CMV_REG_VAL_TEST_PATTERN_ON);

    usleep(1000);

    while(!triggerShutdown)
    {

    	if(requestFrame)
    	{
    		requestFrame = 0;

    		// Toggle the frame request pin.
    		XGpioPs_WritePin(&Gpio, FRAME_REQ_PIN, 1);
    		usleep(1);
    		XGpioPs_WritePin(&Gpio, FRAME_REQ_PIN, 0);
    	}

    	if(updateCMVRegs)
    	{
    		updateCMVRegs = 0;
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_EXP_TIME_L, cmv_Exp_time);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_EXP_KP1_L, cmv_Exp_kp1);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_EXP_KP2_L, cmv_Exp_kp2);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_VTFL, cmv_Vtfl);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_NUMBER_SLOPES, cmv_Number_slopes);
    	}
    }

    cleanup_platform();
    return 0;
}
