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

#define ENC_CTRL_M00_AXI_ARM                0x10000000
#define ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST  0x01000000
#define ENC_CTRL_C_RAM_ADDR_UPDATE_COMPLETE 0x02000000

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void encoderResetRAMAddr(u16 csFlags);

// Public Global Variables ---------------------------------------------------------------------------------------------

Encoder_s * Encoder = (Encoder_s *)(0xA0004000);

// Private Global Variables --------------------------------------------------------------------------------------------

u32 csBaseAddr[16] = {0x20000000, 0x24000000, 0x28000000, 0x2C000000,
                      0x30000000, 0x34000000, 0x38000000, 0x3C000000,
                      0x40000000, 0x44000000, 0x48000000, 0x4C000000,
                      0x50000000, 0x58000000, 0x60000000, 0x68000000};

u32 csFullAddr[16] = {0x20100000, 0x24100000, 0x28100000, 0x2C100000,
                      0x30100000, 0x34100000, 0x38100000, 0x3C100000,
                      0x40100000, 0x44100000, 0x48100000, 0x4C100000,
                      0x50100000, 0x58100000, 0x60100000, 0x68100000};

/*
u32 csFullAddr[16] = {0x23F00000, 0x27F00000, 0x2BF00000, 0x2FF00000,
                      0x33F00000, 0x37F00000, 0x3BF00000, 0x3FF00000,
                      0x43F00000, 0x47F00000, 0x4BF00000, 0x4FF00000,
                      0x57F00000, 0x5FF00000, 0x67F00000, 0x6FF00000};
*/

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void encoderInit(void)
{
	// Configure the Encoder and arm the AXI Master.
	Encoder->q_mult_HH1_HL1_LH1 = 0x00100020;
	Encoder->q_mult_HH2_HL2_LH2 = 0x00200040;
	Encoder->q_mult_HH3_HL3_LH3 = 0x00400040;
	Encoder->control_q_mult_LL3 = ENC_CTRL_M00_AXI_ARM | 0x00000100;

	encoderResetRAMAddr(0xFFFF);
}

void encoderServiceRAMAddr(void)
{
	u16 csFlags = 0x0000;

	for(int iCS = 0; iCS < 16; iCS++)
	{
		if(Encoder->c_RAM_addr[iCS] > csFullAddr[iCS])
		{
			csFlags |= (1 << iCS);
		}
	}

	if(csFlags)
	{
		encoderResetRAMAddr(csFlags);
	}
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void encoderResetRAMAddr(u16 csFlags)
{
	for(int iCS = 0; iCS < 16; iCS++)
	{
		if(csFlags & (1 << iCS))
		{
			Encoder->c_RAM_addr_update[iCS] = csBaseAddr[iCS];
		}
		else
		{
			Encoder->c_RAM_addr_update[iCS] = Encoder->c_RAM_addr[iCS];
		}
	}

	Encoder->control_q_mult_LL3 |= ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST;
	while((Encoder->control_q_mult_LL3 & ENC_CTRL_C_RAM_ADDR_UPDATE_COMPLETE) == 0);
	Encoder->control_q_mult_LL3 &= ~ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST;
}
