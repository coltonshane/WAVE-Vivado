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
#include "frame.h"
#include "cmv12000.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define DARK_FRAME_USER_FLAG  0x80	//   index[7]: Factory, 1: User
#define DARK_FRAME_INDEX_MASK 0x0F  // index[3:0]: Dark Frame Index (0 to 15)

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

DarkFrameColor_s readPixelInLL2(s32 frame, u16 x, u16 y);
u32 bitOffsetInLL2(u16 x, u16 y, u8 color, u16 wLL2);

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

const DarkFrameColor_s dfColorZero = {0, 0, 0, 0};
const DarkFrameColor_s dfColorTest = {64, 64, 64, 64};

// Flash addresses of dark frames.
DarkFrame_s * const dfCold4K = (DarkFrame_s * const) 0xC0900000;
DarkFrame_s * const dfWarm4K = (DarkFrame_s * const) 0xC0910000;
DarkFrame_s * const dfCold2K = (DarkFrame_s * const) 0xC0920000;
DarkFrame_s * const dfWarm2K = (DarkFrame_s * const) 0xC0930000;

// Active dark frame in RAM.
DarkFrame_s dfActive;
// DarkFrame_s dfError;

// HDMI peripheral addresses of dark row and dark column URAMs.
u32 * const hdmiDarkRows =   (u32 * const) 0xA0108000;
u32 * const hdmiDarkCols =   (u32 * const) 0xA0110000;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void hdmiDarkFrameCreate(u16 wFrame, float temp)
{
	DarkFrame_s * dfCold;
	DarkFrame_s * dfWarm;
	float dTemp, wTemp;
	float fVal;

	if(wFrame == 4096)
	{
		dfCold = dfCold4K;
		dfWarm = dfWarm4K;
	}
	else
	{
		dfCold = dfCold2K;
		dfWarm = dfWarm2K;
	}

	dTemp = (float)(dfWarm->temp - dfCold->temp);
	if(dTemp == 0.0f)
	{
		// Both dark frames have the same temperature, just use the first one.
		wTemp = 0.0f;
	}
	else
	{
		// Get an interpolation factor from the temperature passed in.
		if(temp < 0.0f) { temp = 0.0f; }			// Lower limit for extrapolation.
		else if(temp > 70.0f) { temp = 70.0f; }		// Upper limit for extrapolation.
		wTemp = (temp - (float)(dfCold->temp)) / dTemp;
	}

	// Interpolate the dark rows and dark columns.
	// Not testing for saturation since these should be small relative to s16 range.
	for(u16 r = 0; r < DARK_FRAME_H; r++)
	{

		fVal = (float) dfCold->row[r].G1 + wTemp * (float) (dfWarm->row[r].G1 - dfCold->row[r].G1);
		dfActive.row[r].G1 = (s16) fVal;
		fVal = (float) dfCold->row[r].R1 + wTemp * (float) (dfWarm->row[r].R1 - dfCold->row[r].R1);
		dfActive.row[r].R1 = (s16) fVal;
		fVal = (float) dfCold->row[r].B1 + wTemp * (float) (dfWarm->row[r].B1 - dfCold->row[r].B1);
		dfActive.row[r].B1 = (s16) fVal;
		fVal = (float) dfCold->row[r].G2 + wTemp * (float) (dfWarm->row[r].G2 - dfCold->row[r].G2);
		dfActive.row[r].G2 = (s16) fVal;

	}
	for(u16 c = 0; c < DARK_FRAME_H; c++)
	{
		fVal = (float) dfCold->col[c].G1 + wTemp * (float) (dfWarm->col[c].G1 - dfCold->col[c].G1);
		dfActive.col[c].G1 = (s16) fVal;
		fVal = (float) dfCold->col[c].R1 + wTemp * (float) (dfWarm->col[c].R1 - dfCold->col[c].R1);
		dfActive.col[c].R1 = (s16) fVal;
		fVal = (float) dfCold->col[c].B1 + wTemp * (float) (dfWarm->col[c].B1 - dfCold->col[c].B1);
		dfActive.col[c].B1 = (s16) fVal;
		fVal = (float) dfCold->col[c].G2 + wTemp * (float) (dfWarm->col[c].G2 - dfCold->col[c].G2);
		dfActive.col[c].G2 = (s16) fVal;
	}

	// Interpolate the offsets.
	fVal = (float) dfCold->offsetBot + wTemp * (float) (dfWarm->offsetBot - dfCold->offsetBot);
	if(fVal < 0.0f) { fVal = 0.0f; }
	dfActive.offsetBot = (u16) fVal;

	fVal = (float) dfCold->offsetTop + wTemp * (float) (dfWarm->offsetTop - dfCold->offsetTop);
	if(fVal < 0.0f) { fVal = 0.0f; }
	dfActive.offsetTop = (u16) fVal;

	dfActive.temp = temp;
}

void hdmiDarkFrameZero(void)
{
	// Default sensor offset with plenty of black margin.
	dfActive.offsetBot = 512;
	dfActive.offsetTop = 512;

	// Rows
	for(u16 r = 0; r < DARK_FRAME_H; r++)
	{ dfActive.row[r] = dfColorZero; }

	// Columns
	for(u16 c = 0; c < DARK_FRAME_W; c++)
	{ dfActive.col[c] = dfColorZero; }
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

/*
void hdmiDarkFrameAdapt(s32 frame, u32 nSamples, s16 targetBlack)
{
	u16 wFrame, hFrame;
	u16 wLL2, hLL2;

	if((frame < 0) || (nSamples == 0) || (nSamples > 65536))
	{ return; }

	// Dark frame adaptation only allowed in Standby mode.
	if(cState.cSetting[CSETTING_MODE]->val != CSETTING_MODE_STANDBY)
	{ return; }

	wFrame = frameGetHeader(frame)->wFrame;
	hFrame = frameGetHeader(frame)->hFrame;
	wLL2 = wFrame >> 3;
	hLL2 = hFrame >> 3;

	srand(frameGetHeader(frame)->tFrameRead_us & 0xFFFFFFFF);
	for(int n = 0; n < nSamples; n++)
	{
		u32 xSample, ySample;
		u32 xAdapt, yAdapt;
		u32 wAdapt, hAdapt;
		DarkFrameColor_s colorSample;
		int error;

		// Sample a pixel at a random (x, y) location in the frame LL2.
		xSample = rand() % wLL2;
		ySample = rand() % hLL2;
		colorSample = readPixelInLL2(frame, xSample, ySample);

		// Determine the applicable dark frame rows and columns.
		wAdapt = DARK_FRAME_W / wLL2;
		xAdapt = xSample * wAdapt;
		hAdapt = wAdapt;
		yAdapt = (((wLL2 * 3 / 4) - hLL2) / 2 + ySample) * hAdapt;

		// Adapt Rows
		for(int y = yAdapt; y < (yAdapt + hAdapt); y++)
		{
			// G1
			error = targetBlack - (colorSample.G1 - dfActive.row[y].G1);
			if (error > 0) { dfActive.row[y].G1--; }
			else if (error < 0) { dfActive.row[y].G1++; }
			// R1
			error = targetBlack - (colorSample.R1 - dfActive.row[y].R1);
			if (error > 0) { dfActive.row[y].R1--; }
			else if (error < 0) { dfActive.row[y].R1++; }
			// B1
			error = targetBlack - (colorSample.B1 - dfActive.row[y].B1);
			if (error > 0) { dfActive.row[y].B1--; }
			else if (error < 0) { dfActive.row[y].B1++; }
			// G2
			error = targetBlack - (colorSample.G2 - dfActive.row[y].G2);
			if (error > 0) { dfActive.row[y].G2--; }
			else if (error < 0) { dfActive.row[y].G2++; }
		}

		// Adapt Columns
		for(int x = xAdapt; x < (xAdapt + wAdapt); x++)
		{
			// G1
			error = targetBlack - (colorSample.G1 - dfActive.col[x].G1);
			dfError.col[x].G1 += error;
			dfActive.col[x].G1 -= (dfError.col[x].G1 / 256);
			dfError.col[x].G1 = dfError.col[x].G1 % 256;
			// R1
			error = targetBlack - (colorSample.R1 - dfActive.col[x].R1);
			dfError.col[x].R1 += error;
			dfActive.col[x].R1 -= (dfError.col[x].R1 / 256);
			dfError.col[x].R1 = dfError.col[x].R1 % 256;
			// B1
			error = targetBlack - (colorSample.B1 - dfActive.col[x].B1);
			dfError.col[x].B1 += error;
			dfActive.col[x].B1 -= (dfError.col[x].B1 / 256);
			dfError.col[x].B1 = dfError.col[x].B1 % 256;
			// G2
			error = targetBlack - (colorSample.G2 - dfActive.col[x].G2);
			dfError.col[x].G2 += error;
			dfActive.col[x].G2 -= (dfError.col[x].G2 / 256);
			dfError.col[x].G2 = dfError.col[x].G2 % 256;
		}

	}
}
*/

void hdmiDarkFrameApply(u16 wFrame, u16 hFrame)
{
	u16 yStart, yHeight;

	cmvSetOffsets(dfActive.offsetBot, dfActive.offsetTop);

	// Dark frames are always 4K, so scale hFrame by 2x in 2K mode.
	if(wFrame == 4096)
	{ yHeight = hFrame; }
	else
	{ yHeight = 2 * hFrame; }

	// Assume the frame is centered in the sensor.
	yStart = (4096 - yHeight) / 2;

	// Dark row copy of vertical region-of-interest.
	memcpy(hdmiDarkRows, &dfActive.row[yStart], sizeof(DarkFrameColor_s) * yHeight);

	// Dark column copy of fill width.
	memcpy(hdmiDarkCols, &dfActive.col[0], sizeof(DarkFrameColor_s) * DARK_FRAME_W);
}

// Private Function Definitions ----------------------------------------------------------------------------------------

// Read a 10-bit pixel from a given frame's LL2 data.
DarkFrameColor_s readPixelInLL2(s32 frame, u16 x, u16 y)
{
	DarkFrameColor_s colorRead = {0, 0, 0, 0};
	u16 wFrame, hFrame;
	u16 wLL2, hLL2;
	u32 bitDiscard;
	u32 pxDiscard;
	u32 bitOffset;
	u32 byteOffset;
	u32 data;

	if(frame < 0) { return colorRead; }

	wFrame = frameGetHeader(frame)->wFrame;
	hFrame = frameGetHeader(frame)->hFrame;
	wLL2 = wFrame >> 3;
	hLL2 = hFrame >> 3;

	if((x >= wLL2) || (y >= hLL2)) { return colorRead; }

	// Get the number of bits and pixels to discard from the start of LL2.
	bitDiscard = frameGetHeader(frame)->csFIFOState[0] + ((frameGetHeader(frame)->csFIFOFlags >> (16 + 0)) & 0x1) * 64;
	if(wLL2 == 512)
	{ pxDiscard = 6336; }	// 4K Mode
	else
	{ pxDiscard = 3328; }	// 2K Mode

	// TO-DO: Change order of color fields to match Bayer grid and codestream order (many places).

	// R1
	bitOffset = bitDiscard + 10 * pxDiscard + bitOffsetInLL2(x, y, 0, wLL2);
	byteOffset = bitOffset >> 3;
	memcpy((void *)(&data), (void *)((u64)(frameGetHeader(frame)->csAddr[0] + byteOffset)), 4);
	colorRead.R1 = (data >> (bitOffset % 8)) & 0x3FF;

	// G1
	bitOffset = bitDiscard + 10 * pxDiscard + bitOffsetInLL2(x, y, 1, wLL2);
	byteOffset = bitOffset >> 3;
	memcpy((void *)(&data), (void *)((u64)(frameGetHeader(frame)->csAddr[0] + byteOffset)), 4);
	colorRead.G1 = (data >> (bitOffset % 8)) & 0x3FF;

	// G2
	bitOffset = bitDiscard + 10 * pxDiscard + bitOffsetInLL2(x, y, 2, wLL2);
	byteOffset = bitOffset >> 3;
	memcpy((void *)(&data), (void *)((u64)(frameGetHeader(frame)->csAddr[0] + byteOffset)), 4);
	colorRead.G2 = (data >> (bitOffset % 8)) & 0x3FF;

	// B1
	bitOffset = bitDiscard + 10 * pxDiscard + bitOffsetInLL2(x, y, 3, wLL2);
	byteOffset = bitOffset >> 3;
	memcpy((void *)(&data), (void *)((u64)(frameGetHeader(frame)->csAddr[0] + byteOffset)), 4);
	colorRead.B1 = (data >> (bitOffset % 8)) & 0x3FF;

	return colorRead;
}

// Get the bit offset within LL2 (after discarded bits) for a given (x, y, color) pixel.
u32 bitOffsetInLL2(u16 x, u16 y, u8 color, u16 wLL2)
{
	u32 bitsPerRow;
	u32 bitOffset;
	u16 xShifted, xOffset;

	bitsPerRow = 10 * 4 * wLL2;	// 10 [bit/px] * 4 [color] * wLL2 [px/color/row];
	bitOffset = y * bitsPerRow;

	// Account for the horizontal circular wrap of 1px.
	// (The first pixel in LL2 row data is pixel location x = 1 of LL2.)
	xShifted = (x + wLL2 - 1) % wLL2;

	// Map the x location and color to an offset, in [px], within an LL2 row.
	if(wLL2 == 512)
	{
		// 4K Mapping
		xOffset =  ((xShifted >> 0) & 0x03) << 0;	// xOffset[1:0] = xShifted[1:0]
		xOffset += ((xShifted >> 7) & 0x03) << 2;	// xOffset[3:2] = xShifted[8:7]
		xOffset += (color & 0x03) << 4;				// xOffset[5:4] = c[1:0]
		xOffset += ((xShifted >> 2) & 0x1F) << 6;	// xOffset[10:6] = xShifted[6:2]
	}
	else
	{
		// 2K Mapping
		xOffset =  ((xShifted >> 0) & 0x03) << 0;	// xOffset[1:0] = xShifted[1:0]
		xOffset += ((xShifted >> 6) & 0x03) << 2;	// xOffset[3:2] = xShifted[7:6]
		xOffset += (color & 0x03) << 4;				// xOffset[5:4] = c[1:0]
		xOffset += ((xShifted >> 2) & 0x0F) << 6;	// xOffset[9:6] = xShifted[5:2]
	}
	bitOffset += 10 * xOffset;

	return bitOffset;
}

