/*
 * CMV12000 Driver Include
*/

#ifndef __CMV_REGISTERS_INCLUDE__
#define __CMV_REGISTERS_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

#include <stdio.h>
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

// Public Function Prototypes ------------------------------------------------------------------------------------------

void cmvLinkTrain(void);

void cmvRegInit(XSpiPs * spiDevice);
void cmvRegSetMode(XSpiPs * spiDevice);

u16 cmvRegRead(XSpiPs * spiDevice, u8 addr);
void cmvRegWrite(XSpiPs * spiDevice, u8 addr, u16 val);

// Externed Public Global Variables ------------------------------------------------------------------------------------

#endif

