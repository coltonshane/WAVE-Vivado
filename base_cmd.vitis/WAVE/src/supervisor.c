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
#define SUPERVISOR_PREFIX_BATTERY 0xB0
#define SUPERVISOR_PREFIX_REPLY 0xA0
#define SUPERVISOR_COMMAND_EN_3V3SSD 0x01
#define SUPERVISOR_COMMAND_EN_CMV 0x02
#define SUPERVISOR_COMMAND_EN_FAN 0x04
#define SUPERVISOR_COMMAND_FAN_SPEED 0x08
#define SUPERVISOR_REPLY_ENPG_CMV 0x0E
#define SUPERVISOR_REPLY_ENPG_SSD 0x01

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

u8 supervisorVBatt = 120;

// Private Global Variables --------------------------------------------------------------------------------------------

XUartPs Uart0;
XUartPs Uart1;

XUartPs_Config *uart0Config;
XUartPs_Config *uart1Config;

u8 supervisor_command_en = 0;

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

	supervisorSetFan(SUPERVISOR_FAN_HIGH);
}

int supervisorEnableCMVPower(void)
{
	u8 cmvPowerReady = 0x00;
	u8 uart1Reply = 0x00;

	supervisor_command_en |= SUPERVISOR_COMMAND_EN_CMV;

	while(!cmvPowerReady)
	{
	   	XUartPs_SendByte(uart1Config->BaseAddress, SUPERVISOR_PREFIX_COMMAND | supervisor_command_en);
	   	usleep(10000);
	   	// uart1Reply = XUartPs_RecvByte(uart1Config->BaseAddress);
	   	uart1Reply = XUartPs_ReadReg(uart1Config->BaseAddress, XUARTPS_FIFO_OFFSET);
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

int supervisorEnableSSDPower(void)
{
	u8 ssdPowerReady = 0x00;
	u8 uart1Reply = 0x00;

	supervisor_command_en |= SUPERVISOR_COMMAND_EN_3V3SSD;

	while(!ssdPowerReady)
	{
	   	XUartPs_SendByte(uart1Config->BaseAddress, SUPERVISOR_PREFIX_COMMAND | supervisor_command_en);
	   	usleep(10000);
	   	uart1Reply = XUartPs_RecvByte(uart1Config->BaseAddress);
	   	if((uart1Reply & SUPERVISOR_PREFIX_MASK) == SUPERVISOR_PREFIX_REPLY)
	   	{
	   		// Reply prefix is valid, check EN and PG flags.
	   		if((uart1Reply & SUPERVISOR_REPLY_ENPG_SSD) == SUPERVISOR_REPLY_ENPG_SSD)
	   		{
	   			// EN_CMV, PG_3V9, and PG_VDD18 are all set. Okay to proceed.
	   			ssdPowerReady = 0x01;
	   		}
	   	}
	}

	return SUPERVISOR_OK;
}

void supervisorSetFan(u8 fanSpeed)
{
	if(fanSpeed == SUPERVISOR_FAN_OFF)
	{
		supervisor_command_en &= ~SUPERVISOR_COMMAND_EN_FAN;
	}
	else
	{
		supervisor_command_en |= SUPERVISOR_COMMAND_EN_FAN;
		if(fanSpeed == SUPERVISOR_FAN_LOW)
		{
			supervisor_command_en &= ~SUPERVISOR_COMMAND_FAN_SPEED;
		}
		else
		{
			// Any fanSpeed other than OFF or LOW will be HIGH.
			supervisor_command_en |= SUPERVISOR_COMMAND_FAN_SPEED;
		}
	}

	XUartPs_SendByte(uart1Config->BaseAddress, SUPERVISOR_PREFIX_COMMAND | supervisor_command_en);
}

void supervisorService(void)
{
	XUartPs_SendByte(uart1Config->BaseAddress, SUPERVISOR_PREFIX_BATTERY);
	supervisorVBatt = XUartPs_RecvByte(uart1Config->BaseAddress);
}

// Private Function Definitions ----------------------------------------------------------------------------------------
