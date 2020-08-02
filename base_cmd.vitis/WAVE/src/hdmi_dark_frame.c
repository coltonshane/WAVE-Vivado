/*
HDMI Dark Frame Subtraction Module

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
#include "hdmi_dark_frame.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define DARK_FRAME_W 4096
#define DARK_FRAME_H 3072

#define DARK_FRAME_USER_FLAG  0x80	//   index[7]: Factory, 1: User
#define DARK_FRAME_INDEX_MASK 0x0F  // index[3:0]: Dark Frame Index (0 to 15)

// Private Type Definitions --------------------------------------------------------------------------------------------

typedef struct
{
	s16 G1;
	s16 R1;
	s16 B1;
	s16 G2;
} DarkFrameColor_s; // [64B]

typedef struct
{
	DarkFrameColor_s row[DARK_FRAME_H];
	DarkFrameColor_s col[DARK_FRAME_W];
	u8 reserved[8192];
} DarkFrame_s; // [64KiB]

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

DarkFrameColor_s dfColorZero = {0, 0, 0, 0};
DarkFrameColor_s dfColorTest = {64, 64, 64, 64};

// Flash addresses of dark frames.
DarkFrame_s * const dfFactory = (DarkFrame_s * const) 0xC0900000;
DarkFrame_s * const dfUser =    (DarkFrame_s * const) 0xC1100000;

// Active dark frame in RAM, which can be modified by user calibration.
DarkFrame_s dfActive;

// HDMI peripheral addresses of dark row and dark column URAMs.
u32 * const hdmiDarkRows =   (u32 * const) 0xA0108000;
u32 * const hdmiDarkCols =   (u32 * const) 0xA0110000;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void hdmiDarkFrameLoad(u8 index)
{
	DarkFrame_s * dfLoad;

	if(index & DARK_FRAME_USER_FLAG)
	{ dfLoad = &dfUser[index & DARK_FRAME_INDEX_MASK]; }
	else
	{ dfLoad = &dfFactory[index & DARK_FRAME_INDEX_MASK]; }

	memcpy((void *)&dfActive, (void *)dfLoad, sizeof(DarkFrame_s));
}

void hdmiDarkFrameTest(void)
{
	// Rows
	for(u16 r = 0; r < DARK_FRAME_H; r++)
	{
		if (r < (DARK_FRAME_H / 2))
		{ dfActive.row[r] = dfColorTest; }
		else
		{ dfActive.row[r] = dfColorZero; }
	}

	// Columns
	for(u16 c = 0; c < DARK_FRAME_W; c++)
	{
		if (c < (DARK_FRAME_W / 2))
		{ dfActive.col[c] = dfColorTest; }
		else
		{ dfActive.col[c] = dfColorZero; }
	}
}

void hdmiDarkFrameApply(u16 yStart, u16 height)
{
	// Dark row copy of vertical region-of-interest.
	memcpy((void *)hdmiDarkRows, (void *)(&dfActive.row[yStart]), sizeof(DarkFrameColor_s) * height);

	// Dark column copy of fill width.
	memcpy((void *)hdmiDarkCols, (void *)(&dfActive.col[0]), sizeof(DarkFrameColor_s) * DARK_FRAME_W);
}

// Private Function Definitions ----------------------------------------------------------------------------------------
