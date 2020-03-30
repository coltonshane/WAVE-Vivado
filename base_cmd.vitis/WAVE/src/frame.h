/*
WAVE Frame Management Include

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

#ifndef __FRAME_INCLUDE__
#define __FRAME_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

#include "main.h"

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

// Recording States
#define FRAME_REC_STATE_IDLE 		0x00
#define FRAME_REC_STATE_START 		0x01
#define FRAME_REC_STATE_CONTINUE 	0x02

// Public Type Definitions ---------------------------------------------------------------------------------------------

// 512B Frame Header Structure
typedef struct __attribute__((packed))
{
	// Start of Frame [40B]
	char delimeter[12];			// Frame delimiter, always "WAVE HELLO!\n"
	u32 nFrame;					// Frame number.
	u32 nFrameBacklog;			// Frame recording backlog.
	u64 tFrameRead_us;			// Frame read (from sensor) timestamp in [us].
	u64 tFrameWrite_us;			// Frame write (to SSD) timestamp in [us].
	u32 csFIFOFlags;			// Codestream FIFO half-word and overfull flags.

	// Frame Information [8B]
	u16 wFrame;					// Width
	u16 hFrame;					// Height
	u8 reserved0[4];

	// Quantizer Settings [16B]
	u32 q_mult_HH1_HL1_LH1;		// Stage 1 quantizer settings.
	u32 q_mult_HH2_HL2_LH2;		// Stage 2 quantizer settings.
	u8 reserved1[8];

	// Codestream Address and Size [128B]
	u32 csAddr[16];				// Codestream addresses in [B].
	u32 csSize[16];				// Codestream sizes [B].

	// Codestream start-of-frame FIFO and buffer state [32B].
	u16 csFIFOState[16];

	// Temperature Sensors [4B]
	u8 tempPS;
	u8 tempPL;
	u8 tempCMV;
	u8 tempSSD;

	// Padding [284B];
	u8 reserved2[284];
} FrameHeader_s;

// Public Function Prototypes ------------------------------------------------------------------------------------------

void frameInit(void);
void frameService(u8 recState);
int frameLastCaptured(void);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern FrameHeader_s * fhBuffer;

#endif
