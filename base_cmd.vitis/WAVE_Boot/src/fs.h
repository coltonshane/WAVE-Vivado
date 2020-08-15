/*
WAVE Bootloader File System Wrapper Include

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

#ifndef __FS_INCLUDE__
#define __FS_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

#define MAX_CAL_SIZE 0x0800000 //  8MiB
#define MAX_FW_SIZE  0x2800000 // 40MiB

// Public Type Definitions ---------------------------------------------------------------------------------------------

// Public Function Prototypes ------------------------------------------------------------------------------------------

void fsInit(void);
void fsFormat(void);
void fsCreateDir(void);
u32 fsValidateFiles(void);
void fsDeinit(void);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern u8 calBinary[MAX_CAL_SIZE];
extern u32 calSize;

extern u8 fwBinary[MAX_FW_SIZE];
extern u32 fwSize;

#endif
