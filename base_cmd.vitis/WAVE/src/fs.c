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
#include "xrtcpsu.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define RTC_DEVICE_ID              XPAR_XRTCPSU_0_DEVICE_ID

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void fsUpdateFreeSizeGB(void);

// Public Global Variables ---------------------------------------------------------------------------------------------

XRtcPsu RtcPsu;

int nClip = -1;

// Private Global Variables --------------------------------------------------------------------------------------------

FATFS fs;
FIL fil;

int nFile = 0;
u32 fsFreeGB = 0;
u32 fsSizeGB = 0;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void fsInit(void)
{
	FRESULT res;
	/*
	XRtcPsu_Config *RtcPsuConfig;
	u32 tNowRTC;

	RtcPsuConfig = XRtcPsu_LookupConfig(RTC_DEVICE_ID);
	XRtcPsu_CfgInitialize(&RtcPsu, RtcPsuConfig, RtcPsuConfig->BaseAddr);
	tNowRTC = XRtcPsu_GetCurrentTime(&RtcPsu);
	*/

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

	fsGetNextClip();
}

u32 fsGetNextClip(void)
{
	FRESULT fr;
	DIR dirWork;
	FILINFO fInfo;
	char strWorking[8];
	int nClipNext = 0;

	sprintf(strWorking, "c%04d", nClipNext);
	fr = f_opendir(&dirWork, "");

	fr = f_findfirst(&dirWork, &fInfo, "", strWorking);

	while((fr == FR_OK) && fInfo.fname[0])
	{
		nClipNext++;
		sprintf(strWorking, "c%04d", nClipNext);
		fr = f_findfirst(&dirWork, &fInfo, "", strWorking);
	}

	fsUpdateFreeSizeGB();

	return nClipNext;
}

void fsCreateClip(void)
{
	FRESULT res;
	char strWorking[16];

	if((nClip < 0) || (nClip > 9999)) { return; }

	sprintf(strWorking, "c%04d", nClip);
	res = f_mkdir(strWorking);
	if(res) { xil_printf("Warning: New clip creation failed.\r\n"); }
	else { xil_printf("Created new clip.\r\n"); }
}

void fsCloseClip(void)
{
	// Truncate and close any open files first.
	f_truncate(&fil);
	f_close(&fil);

	nClip = fsGetNextClip();
	nFile = 0;
}

void fsCreateFile(void)
{
	FRESULT res;
	char strWorking[32];

	if(nFile > 0)
	{
		res = f_truncate(&fil);
		res = f_close(&fil);
		fsUpdateFreeSizeGB();
	}

	sprintf(strWorking, "/c%04d/f%06d.kwv", nClip, nFile);
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

void fsUpdateFreeSizeGB(void)
{
	FATFS *fsLocal;
	FRESULT res;
	u32 nFreeClusters = 0;

	fsSizeGB = (fs.n_fatent - 2) / 15259;

	res = f_getfree("", &nFreeClusters, &fsLocal);
	if(res == FR_OK) { fsFreeGB = nFreeClusters / 15259; }
	else { fsFreeGB = 0; }
}
