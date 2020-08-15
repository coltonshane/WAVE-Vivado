/*
WAVE Bootloader Main Module

Copyright (C) 2020 by Shane W. Colton

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

#include "main.h"
#include "gpio.h"
#include "supervisor.h"
#include "flash.h"
#include "usb.h"
#include "fs.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define CALIBRATION_FLASH_OFFSET 0x0800000
#define FIRMWARE_FLASH_OFFSET    0x1800000

// Private Type Definitions --------------------------------------------------------------------------------------------

typedef enum
{
	BL_STATE_INIT,
	BL_STATE_IDLE_ENC_SW_UP,
	BL_STATE_IDLE_ENC_SW_DOWN,
	BL_STATE_FLASHING,
	BL_STATE_ERROR
} BootloaderStateType;

// Private Function Prototypes -----------------------------------------------------------------------------------------

void resetToApplication(void);

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

// Registers
u32 * const CSU_MULTI_BOOT = (u32 * const) 0xFFCA0010;
u32 * const RESET_CTRL = (u32 * const) 0xFF5E0218;

BootloaderStateType blState = BL_STATE_INIT;
u32 validFiles = 0;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

int main()
{
	u32 tEncSwDown_ms = 0;

	init_platform();
	Xil_DCacheDisable();
	gpioInit();
	supervisorInit();

	print("WAVE Hello! Bootloader entry.\n\r");

	while(gpioEncSwDown() & (tEncSwDown_ms < 1000))
	{
		usleep(1000);
		tEncSwDown_ms++;
	}

	if(tEncSwDown_ms < 1000)
	{
		goto bl_exit;
	}

	print("Entered firmware update mode.\n\r");
	flashInit();
	usbInit();
	fsFormat();
	fsCreateDir();
	usbStart();
	while(1)
	{
		switch(blState)
		{
		case BL_STATE_INIT:
			gpioServiceLED(LED_SLOW_FLASH);
			if(!gpioEncSwDown())
			{
				blState = BL_STATE_IDLE_ENC_SW_UP;
			}
			break;
		case BL_STATE_IDLE_ENC_SW_UP:
			gpioServiceLED(LED_SLOW_FLASH);
			if(gpioEncSwDown())
			{
				blState = BL_STATE_IDLE_ENC_SW_DOWN;
			}
			break;
		case BL_STATE_IDLE_ENC_SW_DOWN:
			gpioServiceLED(LED_SLOW_FLASH);
			if(!gpioEncSwDown())
			{
				usbStop();
				validFiles = fsValidateFiles();
				if(validFiles)
				{ blState = BL_STATE_FLASHING; }
				else
				{ blState = BL_STATE_ERROR; }
			}
			break;
		case BL_STATE_ERROR:
			gpioServiceLED(LED_ON);
			usbStart();					// To present error log and allow retry.
			if(gpioEncSwDown())
			{
				blState = BL_STATE_INIT;
			}
			break;
		case BL_STATE_FLASHING:
			if(validFiles & CALIBRATION_VALID)
			{
				flashWrite(CALIBRATION_FLASH_OFFSET, calBinary, calSize);
			}
			if(validFiles & FIRMWARE_VALID)
			{
				flashWrite(FIRMWARE_FLASH_OFFSET, fwBinary, fwSize);
			}
			goto bl_exit;
			break;
		}

		usbPoll();
		usleep(1000);
	}

bl_exit:

	print("WAVE Goodbye! Bootloader exit.\n\r");
	resetToApplication();

	// Below here should not be reached.

    cleanup_platform();
    return 0;
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void resetToApplication(void)
{
	// Set multi-boot register to application offset. Offset unit is [32KiB].
	*CSU_MULTI_BOOT = FIRMWARE_FLASH_OFFSET >> 15;

	// Trigger a soft reset.
	*RESET_CTRL |= 0x10;

	while(1);
}
