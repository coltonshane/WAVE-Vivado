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

// Private Global Variables --------------------------------------------------------------------------------------------

FATFS fs;
FIL fil;

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

// Private Function Definitions ----------------------------------------------------------------------------------------
