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
#include "camera_state.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Latency Offsets, 4K Mode
#define PX_COUNT_C_XX1_G1B1_OFFSET_4K	0x00214
#define PX_COUNT_E_XX1_G1B1_OFFSET_4K	0x0021A
#define PX_COUNT_C_XX1_R1G2_OFFSET_4K	0x00215
#define PX_COUNT_E_XX1_R1G2_OFFSET_4K	0x0021B
#define PX_COUNT_C_XX2_OFFSET_4K		0x0062E
#define PX_COUNT_E_XX2_OFFSET_4K		0x00638

// Latency Offsets, 2K Mode
#define PX_COUNT_C_XX1_G1B1_OFFSET_2K	0x00122
#define PX_COUNT_E_XX1_G1B1_OFFSET_2K	0x00128
#define PX_COUNT_C_XX1_R1G2_OFFSET_2K	0x00123
#define PX_COUNT_E_XX1_R1G2_OFFSET_2K	0x00129
#define PX_COUNT_C_XX2_OFFSET_2K		0x0033C
#define PX_COUNT_E_XX2_OFFSET_2K		0x00346

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

// Quantizer Profiles from Most Compression <---> Least Compression
u16 qMult_LH2_HL2[ENCODER_NUM_QMULT_PROFILES] = {16, 20, 29, 32, 37, 43, 52, 64, 86, 86, 128};
u16 qMult_HH2[ENCODER_NUM_QMULT_PROFILES] = {8, 10, 14, 18, 22, 26, 29, 32, 37, 43, 52};
u16 qMult_LH1_HL1[ENCODER_NUM_QMULT_PROFILES] = {8, 10, 12, 14, 16, 18, 22, 26, 29, 32, 43};
u16 qMult_HH1[ENCODER_NUM_QMULT_PROFILES] = {4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void encoderInit(void)
{
	// Configure the Encoder and arm the AXI Master.
	Encoder->q_mult_HH1_HL1_LH1 = 0x00100020;
	Encoder->q_mult_HH2_HL2_LH2 = 0x00200040;
	Encoder->control = ENC_CTRL_M00_AXI_ARM;

	encoderApplyCameraState();

	encoderResetRAMAddr(Encoder, 0xFFFF);
}

void encoderApplyCameraState(void)
{
	if(cState.cSetting[CSETTING_WIDTH]->valArray[cState.cSetting[CSETTING_WIDTH]->val].fVal == 4096.0f)
	{
		// 4K Mode
		Encoder->px_count_XX1_G1B1_offsets = (PX_COUNT_E_XX1_G1B1_OFFSET_4K << 16) | PX_COUNT_C_XX1_G1B1_OFFSET_4K;
		Encoder->px_count_XX1_R1G2_offsets = (PX_COUNT_E_XX1_R1G2_OFFSET_4K << 16) | PX_COUNT_C_XX1_R1G2_OFFSET_4K;
		Encoder->px_count_XX2_offsets = (PX_COUNT_E_XX2_OFFSET_4K << 16) | PX_COUNT_C_XX2_OFFSET_4K;
	}
	else
	{
		// 2K Mode
		Encoder->px_count_XX1_G1B1_offsets = (PX_COUNT_E_XX1_G1B1_OFFSET_2K << 16) | PX_COUNT_C_XX1_G1B1_OFFSET_2K;
		Encoder->px_count_XX1_R1G2_offsets = (PX_COUNT_E_XX1_R1G2_OFFSET_2K << 16) | PX_COUNT_C_XX1_R1G2_OFFSET_2K;
		Encoder->px_count_XX2_offsets = (PX_COUNT_E_XX2_OFFSET_2K << 16) | PX_COUNT_C_XX2_OFFSET_2K;
	}
}

void encoderServiceFOT(Encoder_s * Encoder_snapshot, u8 qMultProfile)
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

	if(qMultProfile < ENCODER_NUM_QMULT_PROFILES)
	{
		Encoder->q_mult_HH1_HL1_LH1 = ((u32)qMult_HH1[qMultProfile] << 16) | (u32)qMult_LH1_HL1[qMultProfile];
		Encoder->q_mult_HH2_HL2_LH2 = ((u32)qMult_HH2[qMultProfile] << 16) | (u32)qMult_LH2_HL2[qMultProfile];
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
