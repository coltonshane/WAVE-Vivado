/*
Terminal/Supervisor UART Driver

Copyright (C) 2019 by Shane W. Colton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

// Include Headers -----------------------------------------------------------------------------------------------------

#include "supervisor.h"
#include "xuartps.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define UART0_DEVICE_ID XPAR_XUARTPS_0_DEVICE_ID	// GPIO/Terminal (External)
#define UART1_DEVICE_ID XPAR_XUARTPS_1_DEVICE_ID	// Supervisor (Internal)

// Supervisor UART protocol.
#define SUPERVISOR_PREFIX_MASK 0xF0
#define SUPERVISOR_PREFIX_COMMAND 0xC0
#define SUPERVISOR_PREFIX_REPLY 0xA0
#define SUPERVISOR_COMMAND_EN_3V3SSD 0x01
#define SUPERVISOR_COMMAND_EN_CMV 0x02
#define SUPERVISOR_REPLY_ENPG_CMV 0x0E

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

XUartPs Uart0;
XUartPs Uart1;

XUartPs_Config *uart0Config;
XUartPs_Config *uart1Config;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void supervisorInit()
{
	// GPIO/Terminal (External)
	uart0Config = XUartPs_LookupConfig(UART0_DEVICE_ID);
	XUartPs_CfgInitialize(&Uart0, uart0Config, uart0Config->BaseAddress);
	XUartPs_SetBaudRate(&Uart0, 115200);

	// Supervisor (Internal)
	uart1Config = XUartPs_LookupConfig(UART1_DEVICE_ID);
	XUartPs_CfgInitialize(&Uart1, uart1Config, uart1Config->BaseAddress);
	XUartPs_SetBaudRate(&Uart1, 115200);
}

int supervisorEnableCMVPower()
{
	u8 cmvPowerReady = 0x00;
	u8 uart1Reply = 0x00;

	while(!cmvPowerReady)
	{
	   	XUartPs_SendByte(uart1Config->BaseAddress, SUPERVISOR_PREFIX_COMMAND | SUPERVISOR_COMMAND_EN_CMV);
	   	usleep(10000);
	   	uart1Reply = XUartPs_RecvByte(uart1Config->BaseAddress);
	   	if((uart1Reply & SUPERVISOR_PREFIX_MASK) == SUPERVISOR_PREFIX_REPLY)
	   	{
	   		// Reply prefix is valid, check EN and PG flags.
	   		if((uart1Reply & SUPERVISOR_REPLY_ENPG_CMV) == SUPERVISOR_REPLY_ENPG_CMV)
	   		{
	   			// EN_CMV, PG_3V9, and PG_VDD18 are all set. Okay to proceed.
	   			cmvPowerReady = 0x01;
	   		}
	   	}
	}

	return SUPERVISOR_OK;
}

// Private Function Definitions ----------------------------------------------------------------------------------------
