/*
WAVE Bootloader File System Wrapper

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
#include "fs.h"
#include "ff.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

u8 fwBinary[MAX_FW_SIZE];
u32 fwSize = 0;

// Private Global Variables --------------------------------------------------------------------------------------------

FATFS fs;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void fsInit(void)
{
	FRESULT res;

	res = f_mount(&fs, "", 0);
	if(res) { xil_printf("Virtual drive mount failed.\r\n"); }
	else { xil_printf("Virtual drive mount successful.\r\n"); }
}

void fsFormat(void)
{
	FRESULT res;
	MKFS_PARM opt;
	BYTE work[FF_MAX_SS];

	f_mount(0, "", 0);

	opt.fmt = FM_FAT32;
	// opt.au_size = 0x10000;
	opt.align = 1;
	opt.n_fat = 1;
	opt.n_root = 512;
	res = f_mkfs("", &opt, work, sizeof work);
	if(res) { xil_printf("Virtual drive format failed.\r\n"); }
	else { xil_printf("Virtual drive format successful.\r\n"); }

	res = f_mount(&fs, "", 0);
	if(res) { xil_printf("Virtual drive mount failed.\r\n"); }
	else { xil_printf("Virtual drive mount successful.\r\n"); }
}

void fsCreateDir(void)
{
	FIL fil;
	f_mkdir("fw");

	f_open(&fil, "FIRMWARE_UPDATE_INSTRUCTIONS.txt", FA_CREATE_ALWAYS | FA_WRITE);
	f_puts("To upload new firmware:\r\n", &fil);
	f_puts("1. Drag the new firmware file (WAVE.bin) into the fw folder.\r\n", &fil);
	f_puts("2. Click the menu scroll wheel.\r\n", &fil);
	f_puts("3. Wait for the camera to automatically restart with the new firmware.\r\n", &fil);
	f_puts("\r\n", &fil);
	f_puts("To cancel the firmware update, restart the camera using the power button.\r\n", &fil);
	f_puts("\r\n", &fil);
	f_puts("The record LED indicates the state of the firmware update:\r\n", &fil);
	f_puts("  SLOW FLASH = Waiting for new firmware.\r\n", &fil);
	f_puts("  FAST FLASH = Firmware update in progress. DO NOT POWER DOWN.\r\n", &fil);
	f_puts("  SOLID RED  = An error occurred. Check FIRMWARE_UPDATE_LOG.txt for details.\r\n", &fil);
	f_close(&fil);

	f_open(&fil, "WHERE_IS_MY_FOOTAGE.txt", FA_CREATE_ALWAYS | FA_WRITE);
	f_puts("Your footage is safe and sound on the internal SSD.\r\n", &fil);
	f_puts("\r\n", &fil);
	f_puts("This is a virtual drive created for uploading new firmware to the camera.\r\n", &fil);
	f_puts("After the firmware update is complete, the camera will restart and the\r\n", &fil);
	f_puts("new firmware will provide normal access to the SSD.\r\n", &fil);
	f_puts("\r\n", &fil);
	f_puts("To cancel the firmware update, restart the camera using the power button.\r\n", &fil);

	f_close(&fil);
}

u32 fsValidateFiles(void)
{
	FIL filLog;
	FIL filFirmware;
	u32 headerSig = 0x00000000;
	u32 nBytesRead = 0;

	f_open(&filLog, "FIRMWARE_UPDATE_LOG.txt", FA_CREATE_ALWAYS | FA_WRITE);

	// 1. Does the firmware file exist?
	if(f_open(&filFirmware, "fw/WAVE.bin", FA_READ) != FR_OK)
	{
		xil_printf("Error: No firmware file found.\r\n");
		f_puts("Error: No firmware file found.\r\n", &filLog);
		f_close(&filLog);
		return 0;
	}

	// 2. Does it have the Header Signature 0x584C4E58 at offset 0x24?
	f_lseek(&filFirmware, 0x24);
	f_read(&filFirmware, &headerSig, 4, &nBytesRead);
	if(headerSig != 0x584C4E58)
	{
		xil_printf("Error: Invalid header signature in firmware file.\r\n");
		f_puts("Error: Invalid header signature in firmware file.\r\n", &filLog);
		f_close(&filLog);
		return 0;
	}

	// N. Copy the firmware binary into RAM and note its size.
	f_lseek(&filFirmware, 0x0);
	f_read(&filFirmware, &fwBinary, MAX_FW_SIZE, &fwSize);
	f_close(&filFirmware);
	xil_printf("Copied %d bytes of firmware into RAM.\r\n", fwSize);

	f_close(&filLog);
	return 1;
}

// Private Function Definitions ----------------------------------------------------------------------------------------
