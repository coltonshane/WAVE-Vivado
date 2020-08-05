/*
HDMI 1D LUT Module

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
#include <math.h>

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Private Type Definitions --------------------------------------------------------------------------------------------

typedef struct
{
	s16 R;
	s16 G;
	s16 B;
	s16 reserved;
} LUT1DColor_s; // [64B]

typedef struct
{
	float RtoR;
	float GtoR;
	float BtoR;
	float RtoG;
	float GtoG;
	float BtoG;
	float RtoB;
	float GtoB;
	float BtoB;
} LUT1DMatrix_s;

typedef struct
{
	LUT1DColor_s lut1D_G1[4096];	// G1 10-bit input to 14-bit color mixer.
	LUT1DColor_s lut1D_R1[4096];	// R1 10-bit input to 14-bit color mixer.
	LUT1DColor_s lut1D_B1[4096];	// B1 10-bit input to 14-bit color mixer.
	LUT1DColor_s lut1D_G2[4096];	// G2 19-bit input to 14-bit color mixer.
	s16 lut1D_R[16384];				// R 14-bit curve.
	s16 lut1D_G[16384];				// G 14-bit curve.
	s16 lut1D_B[16384];				// B 14-bit curve.
	u8 reserved[32768];
} LUT1DPack_s; // [256KiB]

// Private Function Prototypes -----------------------------------------------------------------------------------------

void buildRGBMixerFromMatrix(LUT1DMatrix_s);
void buildRGBCurveFromGamma(float gamma);

// Public Global Variables ---------------------------------------------------------------------------------------------

u32 * const lutG1 =      (u32 * const) 0xA0118000;
u32 * const lutR1 =      (u32 * const) 0xA0120000;
u32 * const lutB1 =      (u32 * const) 0xA0128000;
u32 * const lutG2 =      (u32 * const) 0xA0130000;
u32 * const lutR =       (u32 * const) 0xA0138000;
u32 * const lutG =       (u32 * const) 0xA0140000;
u32 * const lutB =       (u32 * const) 0xA0148000;

const LUT1DMatrix_s mIdentity = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};

LUT1DPack_s lut1dActive;

// Private Global Variables --------------------------------------------------------------------------------------------

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

float debugTestGamma = 1.0f;
void hdmiLUT1DIdentity(void)
{
	buildRGBMixerFromMatrix(mIdentity);
	buildRGBCurveFromGamma(debugTestGamma);
}

void hdmiLUT1DApply(void)
{
	// RGB Color Mixer
	memcpy(lutG1, &lut1dActive.lut1D_G1[0], sizeof(LUT1DColor_s) * 4096);
	memcpy(lutR1, &lut1dActive.lut1D_R1[0], sizeof(LUT1DColor_s) * 4096);
	memcpy(lutB1, &lut1dActive.lut1D_B1[0], sizeof(LUT1DColor_s) * 4096);
	memcpy(lutG2, &lut1dActive.lut1D_G2[0], sizeof(LUT1DColor_s) * 4096);

	// RGB Curves
	memcpy(lutR, &lut1dActive.lut1D_R[0], sizeof(s16) * 16384);
	memcpy(lutG, &lut1dActive.lut1D_G[0], sizeof(s16) * 16384);
	memcpy(lutB, &lut1dActive.lut1D_B[0], sizeof(s16) * 16384);
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void buildRGBMixerFromMatrix(LUT1DMatrix_s m)
{
	float fIn, fOut;
	LUT1DColor_s cOut;

	for(int cIn = 0; cIn < 4096; cIn++)
	{
		if(cIn < 1024)
		{ fIn = (float) cIn / 1024.0f; }	// In Range
		else if(cIn < 2048)
		{ fIn = 1.0f; }						// Clip High
		else
		{ fIn = 0.0f; }						// Clip Low

		// G1/G2 to R
		fOut = (m.GtoR / 2.0f) * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.R = (s16)fOut;

		// G1/G2 to G
		fOut = (m.GtoG / 2.0f) * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.G = (s16)fOut;

		// G1/G2 to B
		fOut = (m.GtoB / 2.0f) * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.B = (s16)fOut;

		lut1dActive.lut1D_G1[cIn] = cOut;
		lut1dActive.lut1D_G2[cIn] = cOut;

		// R1 to R
		fOut = m.RtoR * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.R = (s16)fOut;

		// R1 to G
		fOut = m.RtoG * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.G = (s16)fOut;

		// R1 to B
		fOut = m.RtoB * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.B = (s16)fOut;

		lut1dActive.lut1D_R1[cIn] = cOut;

		// B1 to R
		fOut = m.BtoR * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.R = (s16)fOut;

		// B1 to G
		fOut = m.BtoG * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.G = (s16)fOut;

		// B1 to B
		fOut = m.BtoB * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.B = (s16)fOut;

		lut1dActive.lut1D_B1[cIn] = cOut;
	}
}

void buildRGBCurveFromGamma(float gamma)
{
	float fIn, fOut;

	for(int cIn = 0; cIn < 16384; cIn++)
	{
		fIn = cIn / 16384.0f;
		fOut = powf(fIn, 1.0f / gamma) * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }

		lut1dActive.lut1D_R[cIn] = (s16)fOut;
		lut1dActive.lut1D_G[cIn] = (s16)fOut;
		lut1dActive.lut1D_B[cIn] = (s16)fOut;
	}
}
