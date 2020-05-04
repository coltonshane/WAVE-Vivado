/*
GPIO Driver Include

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

#ifndef __GPIO_INCLUDE__
#define __GPIO_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

#include "main.h"
#include "xgpiops.h"

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

// MIO Pin Assignments
#define UI_BANK 2
#define UI_MASK 			0x0003C000
#define UI_REC_SW_MASK 		0x00004000
#define UI_ENC_A_MASK    	0x00008000
#define UI_ENC_A_POS				15
#define UI_ENC_B_MASK		0x00010000
#define UI_ENC_B_POS	        	16
#define UI_ENC_SW_MASK		0x00020000
#define REC_SW_PIN 66		// Bank 2, Pin 14, MIO 66
#define ENC_A_PIN 67		// Bank 2, Pin 15, MIO 67
#define ENC_B_PIN 68		// Bank 2, Pin 16, MIO 68
#define ENC_SW_PIN 69		// Bank 2, Pin 17, MIO 69

// EMIO Pin Assignments
#define GPIO1_PIN 78		// Bank 3, Pin 0, EMIO 0
#define GPIO2_PIN 79		// Bank 3, Pin 1, EMIO 1
#define GPIO3_PIN 80		// Bank 3, Pin 2, EMIO 2
#define GPIO4_PIN 81		// Bank 3, Pin 3, EMIO 3
#define LVDS_CLK_EN_PIN 82	// Bank 3, Pin 4, EMIO 4
#define PX_IN_RST_PIN 83	// Bank 3, Pin 5, EMIO 5
#define GPIO_SEL_UART0 84	// Bank 3, Pin 6, EMIO 6
// Unused 85				// Bank 3, Pin 7, EMIO 7
#define CMV_NRST_PIN 86		// Bank 3, Pin 8, EMIO 8
#define T_EXP1_PIN 87		// Bank 3, Pin 9, EMIO 9
#define T_EXP2_PIN 88		// Bank 3, Pin 10, EMIO 10

// Public Type Definitions ---------------------------------------------------------------------------------------------

// Public Function Prototypes ------------------------------------------------------------------------------------------

void gpioInit(void);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern XGpioPs Gpio;

#endif
