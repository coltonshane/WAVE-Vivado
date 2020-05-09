/*
WAVE File System Wrapper

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

#include "fs.h"
#include "ff.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

FATFS fs;
FIL fil;

int nClip = -1;
int nFile = 0;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void fsInit(void)
{
	FRESULT res;

	res = f_mount(&fs, "", 0);
	if(res) { xil_printf("SSD mount failed.\r\n"); }
	else { xil_printf("SSD mount successful.\r\n"); }

	nClip = fsGetNextClip();
}

void fsFormat(void)
{
	FRESULT res;
	MKFS_PARM opt;
	BYTE work[FF_MAX_SS];

	f_mount(0, "", 0);

	opt.fmt = FM_FAT32;
	opt.au_size = 0x10000;
	opt.align = 1;
	opt.n_fat = 1;
	opt.n_root = 512;
	res = f_mkfs("", &opt, work, sizeof work);
	if(res) { xil_printf("SSD format failed.\r\n"); }
	else { xil_printf("SSD format successful.\r\n"); }

	res = f_mount(&fs, "", 0);
	if(res) { xil_printf("SSD mount failed.\r\n"); }
	else { xil_printf("SSD mount successful.\r\n"); }
}

u32 fsGetNextClip(void)
{
	FRESULT fr;
	DIR dirWork;
	FILINFO fInfo;
	char strWorking[8];
	int nClipNext = 0;

	sprintf(strWorking, "c%04d\n", nClipNext);
	fr = f_findfirst(&dirWork, &fInfo, "", strWorking);

	while(fr == FR_OK)
	{
		nClipNext++;
		sprintf(strWorking, "c%04d\n", nClipNext);
		fr = f_findfirst(&dirWork, &fInfo, "", strWorking);
	}

	return nClipNext;
}

void fsCreateClip(void)
{
	FRESULT res;
	char strWorking[16];

	nClip++;

	sprintf(strWorking, "c%04d\n", nClip);
	res = f_mkdir(strWorking);
	if(res) { xil_printf("Warning: New clip creation failed.\r\n"); }
	else { xil_printf("Created new clip.\r\n"); }
}

void fsCreateFile(void)
{
	FRESULT res;
	char strWorking[32];

	if(nFile > 0)
	{
		res = f_truncate(&fil);
		res = f_close(&fil);
	}

	sprintf(strWorking, "/c%04d/f%06d.bin\n", nClip, nFile);
	res = f_open(&fil, strWorking, FA_CREATE_NEW | FA_WRITE);
	res = f_expand(&fil, 0x1000000, 1);		// Reserve 16MiB.

	nFile++;

	(void) res;
}

void fsWriteFile(u64 srcAddress, u32 size)
{
	FRESULT res;
	UINT bw;

	res = f_write(&fil, (u8 *) srcAddress, size, &bw);
	(void) res;
}

void fsDeinit(void)
{
	FRESULT res;

	res = f_truncate(&fil);
	res = f_close(&fil);
	res = f_mount(0, "", 0);
	(void) res;
}

// Private Function Definitions ----------------------------------------------------------------------------------------
