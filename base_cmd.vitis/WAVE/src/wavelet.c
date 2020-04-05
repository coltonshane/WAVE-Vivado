/*
Wavelet Stage Driver

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

#include "wavelet.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Latency Offsets, 4K Mode
#define PX_COUNT_V1_G1B1_OFFSET_4K 		0x000F
#define PX_COUNT_V1_R1G2_OFFSET_4K		0x0010
#define PX_COUNT_H2_OFFSET_4K			0x0216
#define PX_COUNT_V2_OFFSET_4K			0x0224

// Latency Offsets, 2K Mode
#define PX_COUNT_V1_G1B1_OFFSET_2K 		0x001D
#define PX_COUNT_V1_R1G2_OFFSET_2K		0x001E
#define PX_COUNT_H2_OFFSET_2K			0x0124
#define PX_COUNT_V2_OFFSET_2K			0x0132

// Private Type Definitions --------------------------------------------------------------------------------------------

typedef struct
{
	u32 SS;
	u32 px_count_v1_R1G2_G1B1_offsets;
	u32 debug_XX1_px_count_trig;
	u32 debug_core_XX1_addr;
	u32 debug_core_HH1_data;
	u32 debug_core_HL1_data;
	u32 debug_core_LH1_data;
	u32 debug_core_LL1_data;
} Wavelet_S1_s;

typedef struct
{
	u32 SS;
	u32 px_count_v2_h2_offsets;
	u32 debug_XX2_px_count_trig;
	u32 debug_core_XX2_addr;
	u32 debug_core_HH2_data;
	u32 debug_core_HL2_data;
	u32 debug_core_LH2_data;
	u32 debug_core_LL2_data;
} Wavelet_S2_s;

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

Wavelet_S1_s * Wavelet_S1 = (Wavelet_S1_s *)(0xA0001000);
Wavelet_S2_s * Wavelet_S2 = (Wavelet_S2_s *)(0xA0002000);

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void waveletInit(void)
{
	waveletSetMode(1);
}

void waveletSetMode(u8 SS)
{
	if(SS)
	{
		// 2K Mode
		Wavelet_S1->SS = 1;
		Wavelet_S1->px_count_v1_R1G2_G1B1_offsets = (PX_COUNT_V1_R1G2_OFFSET_2K << 16) | PX_COUNT_V1_G1B1_OFFSET_2K;

		Wavelet_S2->SS = 1;
		Wavelet_S2->px_count_v2_h2_offsets = (PX_COUNT_V2_OFFSET_2K << 16) | PX_COUNT_H2_OFFSET_2K;
	}
	else
	{
		// 4K Mode
		Wavelet_S1->SS = 0;
		Wavelet_S1->px_count_v1_R1G2_G1B1_offsets = (PX_COUNT_V1_R1G2_OFFSET_4K << 16) | PX_COUNT_V1_G1B1_OFFSET_4K;

		Wavelet_S2->SS = 0;
		Wavelet_S2->px_count_v2_h2_offsets = (PX_COUNT_V2_OFFSET_4K << 16) | PX_COUNT_H2_OFFSET_4K;
	}
}

// Private Function Definitions ----------------------------------------------------------------------------------------
