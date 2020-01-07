/*
CMV12000 Driver Include

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

#ifndef __CMV_REGISTERS_INCLUDE__
#define __CMV_REGISTERS_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

#include "main.h"
#include "xspips.h"

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

// Registers
#define CMV_REG_ADDR_EXP_TIME_L 71
#define CMV_REG_ADDR_EXP_TIME_H 72

#define CMV_REG_ADDR_EXP_KP1_L 75
#define CMV_REG_ADDR_EXP_KP1_H 76
#define CMV_REG_ADDR_EXP_KP2_L 77
#define CMV_REG_ADDR_EXP_KP2_H 78
#define CMV_REG_ADDR_NUMBER_SLOPES 79
#define CMV_REG_ADDR_NUMBER_FRAMES 80
#define CMV_REG_ADDR_VTFL 106

#define CMV_REG_ADDR_PGA_GAIN 115
#define CMV_REG_VAL_PGA_GAIN_X1 0
#define CMV_REG_VAL_PGA_GAIN_X2 1
#define CMV_REG_VAL_PGA_GAIN_X3 3
#define CMV_REG_VAL_PGA_GAIN_X4 7

#define CMV_REG_ADDR_DIG_GAIN 117

#define CMV_REG_ADDR_TEST_PATTERN 122
#define CMV_REG_VAL_TEST_PATTERN_OFF 32
#define CMV_REG_VAL_TEST_PATTERN_ON 35

// Public Type Definitions ---------------------------------------------------------------------------------------------

typedef struct
{
	u32 ch[65];				// [63:0] are pixel channels, [64] is the control channel
	u32 px_count_limit;		// Limit for pixel counter, to stop capture in mid-frame for debugging.
	u32 px_count;			// Master pixel count, in increments of 64px.
	u32 FOT_int;			// Frame Overhead Time (FOT) interrupt flag.
} CMV_Input_s;

typedef struct
{
	u16 Exp_time;
	u16 Exp_kp1;
	u16 Exp_kp2;
	u16 Vtfl;
	u16 Number_slopes;
	u16 Number_frames;
} CMV_Settings_s;

// Public Function Prototypes ------------------------------------------------------------------------------------------

void cmvInit(void);
void cmvUpdateSettings(void);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern CMV_Input_s * CMV_Input;
extern CMV_Settings_s CMV_Settings;

#endif

