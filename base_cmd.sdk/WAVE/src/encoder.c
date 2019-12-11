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

// Public Global Variables ---------------------------------------------------------------------------------------------

Encoder_s * Encoder = (Encoder_s *)(0xA0004000);

// Private Global Variables --------------------------------------------------------------------------------------------

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void encoderInit(void)
{
	// Configure the Encoder and arm the AXI Master.
	Encoder->q_mult_HH1_HL1_LH1 = 0x00100020;
	Encoder->q_mult_HH2_HL2_LH2 = 0x00200040;
	Encoder->q_mult_HH3_HL3_LH3 = 0x00400040;
	Encoder->control_q_mult_LL3 = ENC_CTRL_M00_AXI_ARM | 0x00000100;

	encoderResetRAMAddr();
}

void encoderResetRAMAddr(void)
{
	Encoder->c_RAM_addr_update[0] = 0x20000000;  // HH1.R1
	Encoder->c_RAM_addr_update[1] = 0x24000000;  // HH1.G1
	Encoder->c_RAM_addr_update[2] = 0x28000000;  // HH1.G2
	Encoder->c_RAM_addr_update[3] = 0x2C000000;  // HH1.B1
	Encoder->c_RAM_addr_update[4] = 0x30000000;  // HL1.R1
	Encoder->c_RAM_addr_update[5] = 0x34000000;  // HL1.G1
	Encoder->c_RAM_addr_update[6] = 0x38000000;  // HL1.G2
	Encoder->c_RAM_addr_update[7] = 0x3C000000;  // HL1.B1
	Encoder->c_RAM_addr_update[8] = 0x40000000;  // LH1.R1
	Encoder->c_RAM_addr_update[9] = 0x44000000;  // LH1.G1
	Encoder->c_RAM_addr_update[10] = 0x48000000; // LH1.G2
	Encoder->c_RAM_addr_update[11] = 0x4C000000; // LH1.B1
	Encoder->c_RAM_addr_update[12] = 0x50000000; // HH2
	Encoder->c_RAM_addr_update[13] = 0x58000000; // HL2
	Encoder->c_RAM_addr_update[14] = 0x60000000; // LH2
	Encoder->c_RAM_addr_update[15] = 0x68000000; // XX3

	Encoder->control_q_mult_LL3 |= ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST;
	while((Encoder->control_q_mult_LL3 & ENC_CTRL_C_RAM_ADDR_UPDATE_COMPLETE) == 0);
	Encoder->control_q_mult_LL3 &= ~ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST;
}

// Private Function Definitions ----------------------------------------------------------------------------------------
