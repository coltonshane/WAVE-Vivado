/*
WAVE Main Include

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

#ifndef __MAIN_INCLUDE__
#define __MAIN_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

#include <stdio.h>
#include <stdlib.h>
#include "platform.h"
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xtime_l.h"
#include "sleep.h"

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

#define US_PER_COUNT 1000 / (COUNTS_PER_SECOND / 1000)

// Public Type Definitions ---------------------------------------------------------------------------------------------

// Public Function Prototypes ------------------------------------------------------------------------------------------

void mainServiceTrigger(void);
float psplGetTemp(u16 * psplTemp);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern u16 * psTemp;
extern u16 * plTemp;

#endif
