/*
HDMI 3D LUT Module

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
#include "hdmi_lut3d.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Private Type Definitions --------------------------------------------------------------------------------------------

typedef struct
{
	union { s16 c0, c4; };
	union { s16 c1, c5; };
	union { s16 c2, c6; };
	union { s16 c3, c7; };
} LUT3DCoefGroup_s; // [64B]

typedef struct
{
	LUT3DCoefGroup_s lut3D_C30_R[4096];	// R C0-C3 coefficients.
	LUT3DCoefGroup_s lut3D_C74_R[4096];	// R C4-C7 coefficients.
	LUT3DCoefGroup_s lut3D_C30_G[4096];	// G C0-C3 coefficients.
	LUT3DCoefGroup_s lut3D_C74_G[4096];	// G C4-C7 coefficients.
	LUT3DCoefGroup_s lut3D_C30_B[4096];	// B C0-C3 coefficients.
	LUT3DCoefGroup_s lut3D_C74_B[4096];	// B C4-C7 coefficients.
	u8 reserved[65536];
} LUT3DPack_s; // [256KiB]

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

u32 * const lut3dC30R =  (u32 * const) 0xA0150000;
u32 * const lut3dC74R =  (u32 * const) 0xA0158000;
u32 * const lut3dC30G =  (u32 * const) 0xA0160000;
u32 * const lut3dC74G =  (u32 * const) 0xA0168000;
u32 * const lut3dC30B =  (u32 * const) 0xA0170000;
u32 * const lut3dC74B =  (u32 * const) 0xA0178000;

LUT3DPack_s lut3dActive;

// Private Global Variables --------------------------------------------------------------------------------------------

// 3D LUT Curves
s16 linFull[] = {0, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360};
s16 dlinFull[] = {1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024};

s16 lin709[] = {1024, 1920, 2816, 3712, 4608, 5504, 6400, 7296, 8192, 9088, 9984, 10880, 11776, 12672, 13568, 14464};
s16 dlin709[] = {896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void hdmiLUT3DIdentity(hdmiLUT3DRangeType range)
{
	int lutIndex;
	s16 * lut;
	s16 * dlut;

	if(range == HDMI_LUT3D_RANGE_FULL)
	{
		lut = linFull;
		dlut = dlinFull;
	}
	else
	{
		lut = lin709;
		dlut = dlin709;
	}

	for(int b = 0; b < 16; b++)
	{
		for(int g = 0; g < 16; g++)
		{
			for(int r = 0; r < 16; r++)
			{
				lutIndex = (b << 8) + (g << 4) + r;

				// Red Output
				lut3dActive.lut3D_C30_R[lutIndex].c0 = lut[r];
				lut3dActive.lut3D_C30_R[lutIndex].c1 = 0;
				lut3dActive.lut3D_C30_R[lutIndex].c2 = dlut[r];
				lut3dActive.lut3D_C30_R[lutIndex].c3 = 0;
				lut3dActive.lut3D_C74_R[lutIndex].c4 = 0;
				lut3dActive.lut3D_C74_R[lutIndex].c5 = 0;
				lut3dActive.lut3D_C74_R[lutIndex].c6 = 0;
				lut3dActive.lut3D_C74_R[lutIndex].c7 = 0;

				// Green Output
				lut3dActive.lut3D_C30_G[lutIndex].c0 = lut[g];
				lut3dActive.lut3D_C30_G[lutIndex].c1 = 0;
				lut3dActive.lut3D_C30_G[lutIndex].c2 = 0;
				lut3dActive.lut3D_C30_G[lutIndex].c3 = dlut[g];
				lut3dActive.lut3D_C74_G[lutIndex].c4 = 0;
				lut3dActive.lut3D_C74_G[lutIndex].c5 = 0;
				lut3dActive.lut3D_C74_G[lutIndex].c6 = 0;
				lut3dActive.lut3D_C74_G[lutIndex].c7 = 0;

				// Blue Output
				lut3dActive.lut3D_C30_B[lutIndex].c0 = lut[b];
				lut3dActive.lut3D_C30_B[lutIndex].c1 = dlut[b];
				lut3dActive.lut3D_C30_B[lutIndex].c2 = 0;
				lut3dActive.lut3D_C30_B[lutIndex].c3 = 0;
				lut3dActive.lut3D_C74_B[lutIndex].c4 = 0;
				lut3dActive.lut3D_C74_B[lutIndex].c5 = 0;
				lut3dActive.lut3D_C74_B[lutIndex].c6 = 0;
				lut3dActive.lut3D_C74_B[lutIndex].c7 = 0;
			}
		}
	}
}

void hdmiLUT3DApply(void)
{
	memcpy(lut3dC30R, &lut3dActive.lut3D_C30_R[0], sizeof(LUT3DCoefGroup_s) * 4096);
	memcpy(lut3dC74R, &lut3dActive.lut3D_C74_R[0], sizeof(LUT3DCoefGroup_s) * 4096);
	memcpy(lut3dC30G, &lut3dActive.lut3D_C30_G[0], sizeof(LUT3DCoefGroup_s) * 4096);
	memcpy(lut3dC74G, &lut3dActive.lut3D_C74_G[0], sizeof(LUT3DCoefGroup_s) * 4096);
	memcpy(lut3dC30B, &lut3dActive.lut3D_C30_B[0], sizeof(LUT3DCoefGroup_s) * 4096);
	memcpy(lut3dC74B, &lut3dActive.lut3D_C74_B[0], sizeof(LUT3DCoefGroup_s) * 4096);
}

// Private Function Definitions ----------------------------------------------------------------------------------------
