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
#include "hdmi_lut1d.h"
#include "cmv12000.h"

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

// Recording States
#define FRAME_REC_STATE_IDLE 		0x00
#define FRAME_REC_STATE_START 		0x01
#define FRAME_REC_STATE_CONTINUE 	0x02

// Public Type Definitions ---------------------------------------------------------------------------------------------

// 512B Clip Header Structure
typedef struct __attribute__((packed))
{
	char strDelimiter[12];		// Clip delimiter, always "WAVE HELLO!\n"
	Version_s version;			// Version number of the WAVE file format.
	u16 wFrame;					// Frame width in [px].
	u16 hFrame;					// Frame height in [px].
	float fps;					// Target capture frame rate in [fps].
	float shutterAngle;			// Target shutter angle in [deg].
	float colorTemp;			// Color temperature hint in [K].
	u8 gain;					// Enumerated gain setting (0: Linear, 1: HDR).
	u8 reserved0[3];			// Reserved.
	LUT1DMatrix_s m5600K;		// Color matrix for 5600K.
	LUT1DMatrix_s m3200K;		// Color matrix for 3200K.
	float hdrTExp1;				// Multi-slope HDR kneepoint 1 time.
	float hdrKp1;				// Multi-slope HDR kneepoint 1 level.
	float hdrKp1Window;			// Multi-slope HDR kneepoint 1 level window.
	float hdrTExp2;				// Multi-slope HDR kneepoint 2 time.
	float hdrKp2;				// Multi-slope HDR kneepoint 2 level.
	float hdrKp2Window;			// Multi-slope HDR kneepoint 2 level window.
	u8 reserved1[124];			// Reserved.
	CMV_Settings_s cmvSettings; // CMV12000 image sensor settings registers.
	u8 reserved2[202];			// Reserved.
} ClipHeader_s;

// 512B Frame Header Structure
typedef struct __attribute__((packed))
{
	// Start of Frame [40B]
	char strDelimiter[12];		// Frame delimiter, always "WAVE HELLO!\n"
	u32 nFrame;					// Frame number.
	u32 nFrameBacklog;			// Frame recording backlog.
	u64 tFrameRead_us;			// Frame read (from sensor) timestamp in [us].
	u64 tFrameWrite_us;			// Frame write (to SSD) timestamp in [us].
	u32 csFIFOFlags;			// Codestream FIFO half-word and overfull flags.

	// Frame Information [8B]
	u16 wFrame;					// Width
	u16 hFrame;					// Height
	u8  reserved0[4];			// Reserved.

	// Quantizer Settings [16B]
	u32 q_mult_HH1_HL1_LH1;		// Stage 1 quantizer settings.
	u32 q_mult_HH2_HL2_LH2;		// Stage 2 quantizer settings.
	u8 reserved1[8];			// Reserved.

	// Codestream Address and Size [128B]
	u32 csAddr[16];				// Codestream addresses in [B].
	u32 csSize[16];				// Codestream sizes [B].

	// Codestream start-of-frame FIFO and buffer state [32B].
	u16 csFIFOState[16];

	// Temperature Sensors [4B]
	s8 tempPS;					// CPU Processing System temperature in [ºC].
	s8 tempPL;					// CPU Programmable Logic temperature in [ºC].
	s8 tempCMV;					// Image sensor temperature in [ºC].
	s8 tempSSD;					// SSD temperature in [ºC].

	// Padding [284B];
	u8 reserved2[284];			// Reserved.
} FrameHeader_s;

// Public Function Prototypes ------------------------------------------------------------------------------------------

void frameInit(void);
void frameApplyCameraState(void);
void frameCreateClip(void);
void frameAddToClip(void);
void frameCloseClip(void);
int frameLastCapturedIndex(void);
FrameHeader_s * frameGetHeader(u32 iFrame);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern u8 frameCompressionProfile;
extern float frameCompressionRatio;

#endif
