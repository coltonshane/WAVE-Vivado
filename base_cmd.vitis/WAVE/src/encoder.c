/*
Encoder Stage Driver

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

#include "encoder.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Latency Offsets
#define PX_COUNT_C_XX1_G1B1_OFFSET_4K	0x00214
#define PX_COUNT_E_XX1_G1B1_OFFSET_4K	0x0021A
#define PX_COUNT_C_XX1_R1G2_OFFSET_4K	0x00215
#define PX_COUNT_E_XX1_R1G2_OFFSET_4K	0x0021B
#define PX_COUNT_C_XX2_OFFSET_4K		0x0062E
#define PX_COUNT_E_XX2_OFFSET_4K		0x00638

#define ENC_CTRL_M00_AXI_ARM                0x10000000
#define ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST  0x01000000
#define ENC_CTRL_C_RAM_ADDR_UPDATE_COMPLETE 0x02000000

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void encoderResetRAMAddr(Encoder_s * Encoder_local, u16 csFlags);

// Public Global Variables ---------------------------------------------------------------------------------------------

Encoder_s * Encoder = (Encoder_s *)(0xA0004000);

// Private Global Variables --------------------------------------------------------------------------------------------

u32 csBaseAddr[16] = {0x20000000, 0x38000000, 0x3E000000, 0x44000000,
                      0x4A000000, 0x4D000000, 0x50000000, 0x53000000,
                      0x56000000, 0x59000000, 0x5C000000, 0x5F000000,
                      0x62000000, 0x65000000, 0x68000000, 0x6B000000};

u32 csFullAddr[16] = {0x37F00000, 0x3DF00000, 0x43F00000, 0x49F00000,
                      0x4CF00000, 0x4FF00000, 0x52F00000, 0x55F00000,
                      0x58F00000, 0x5BF00000, 0x5EF00000, 0x61F00000,
                      0x64F00000, 0x67F00000, 0x6AF00000, 0x6DF00000};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void encoderInit(void)
{
	// Configure the Encoder and arm the AXI Master.
	Encoder->q_mult_HH1_HL1_LH1 = 0x00100020;
	Encoder->q_mult_HH2_HL2_LH2 = 0x00200040;
	Encoder->control = ENC_CTRL_M00_AXI_ARM;

	encoderSetMode(0);

	encoderResetRAMAddr(Encoder, 0xFFFF);
}

void encoderSetMode(u8 SS)
{
	if(SS)
	{
		// 2K Mode
	}
	else
	{
		// 4K Mode
		Encoder->px_count_XX1_G1B1_offsets = (PX_COUNT_E_XX1_G1B1_OFFSET_4K << 16) | PX_COUNT_C_XX1_G1B1_OFFSET_4K;
		Encoder->px_count_XX1_R1G2_offsets = (PX_COUNT_E_XX1_R1G2_OFFSET_4K << 16) | PX_COUNT_C_XX1_R1G2_OFFSET_4K;
		Encoder->px_count_XX2_offsets = (PX_COUNT_E_XX2_OFFSET_4K << 16) | PX_COUNT_C_XX2_OFFSET_4K;
	}
}

void encoderServiceRAMAddr(Encoder_s * Encoder_snapshot)
{
	u16 csFlags = 0x0000;

	for(int iCS = 0; iCS < 16; iCS++)
	{
		if(Encoder_snapshot->c_RAM_addr[iCS] > csFullAddr[iCS])
		{
			csFlags |= (1 << iCS);
		}
	}

	if(csFlags)
	{
		encoderResetRAMAddr(Encoder_snapshot, csFlags);
	}
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void encoderResetRAMAddr(Encoder_s * Encoder_snapshot, u16 csFlags)
{
	for(int iCS = 0; iCS < 16; iCS++)
	{
		if(csFlags & (1 << iCS))
		{
			Encoder->c_RAM_addr_update[iCS] = csBaseAddr[iCS];
		}
		else
		{
			Encoder->c_RAM_addr_update[iCS] = Encoder_snapshot->c_RAM_addr[iCS];
		}
	}

	Encoder->control |= ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST;
	while((Encoder->control & ENC_CTRL_C_RAM_ADDR_UPDATE_COMPLETE) == 0);
	Encoder->control &= ~ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST;
}
