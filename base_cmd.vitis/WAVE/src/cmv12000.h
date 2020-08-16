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
#define CMV_REG_ADDR_OFFSET_BOT 87
#define CMV_REG_ADDR_OFFSET_TOP 88
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

#define CMV_REG_ADDR_TEMP_SENSOR 127

// Public Type Definitions ---------------------------------------------------------------------------------------------

typedef struct
{
	u32 ch[65];				// [63:0] are pixel channels, [64] is the control channel
	u32 px_count_limit;		// Limit for pixel counter, to stop capture in mid-frame for debugging.
	u32 px_count;			// Master pixel count, in increments of 64px.
	u32 FOT_int;			// Frame Overhead Time (FOT) interrupt flag.
	u32 frame_interval;		// Frame timer interval in [us/60].
	u32 FRAME_REQ_on;		// FRAME_REQ pulse time in [us/60].
	u32 T_EXP1_on;			// T_EXP1 pulse time in [us/60].
	u32 T_EXP2_on;			// T_EXP2 ulse time in [us/60].
	u32 exp_bias;			// Black level bias during INTE1.
} CMV_Input_s;

typedef struct __attribute__((packed))
{
	u16 Number_lines_tot;		// Register 1
	u16 Y_start_1;				// Register 2
	u16 Sub_offset;				// Register 66
	u16 Sub_step;				// Register 67
	u16 Sub_en;					// Register 68
	u16 Exp_time_L;				// Register 71
	u16 Exp_time_H;				// Register 72
	u16 Exp_kp1_L;				// Register 75
	u16 Exp_kp1_H;				// Register 76
	u16 Exp_kp2_L;				// Register 77
	u16 Exp_kp2_H;				// Register 78
	u16 Number_slopes;			// Register 79
	u16 Setting_1;				// Register 82
	u16 Setting_2;				// Register 83
	u16 Setting_3;				// Register 84
	u16 Setting_4;				// Register 85
	u16 Setting_5;				// Register 86
	u16 Offset_bot;				// Register 87
	u16 Offset_top;				// Register 88
	u16 Reg_98;					// Register 98
	u16 Vtfl;					// Register 106
	u16 Setting_6;				// Register 113
	u16 Setting_7;				// Register 114
	u16 PGA_gain;				// Register 115
	u16 DIG_gain;				// Register 117
	u16 Test_pattern;			// Register 122
	u16 Temp_sensor;			// Register 127
} CMV_Settings_s;

// Public Function Prototypes ------------------------------------------------------------------------------------------

void cmvInit(void);
void cmvService(void);
void cmvApplyCameraState(void);
u32 cmvGetOffsets(void);
void cmvSetOffsets(u16 offsetBot, u16 offsetTop);
u16 cmvGetVtfl(void);
void cmvSetVtfl(u8 Vtfl2, u8 Vtfl3);
float cmvGetTemp(void);
u32 cmvGetExposure(void);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern CMV_Input_s * CMV_Input;
extern CMV_Settings_s CMV_Settings_W;

#endif

