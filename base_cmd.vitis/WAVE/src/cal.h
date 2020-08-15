/*
Calibration Include

Copyright (C) 2020 by Shane W. Colton

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

#ifndef __CAL_INCLUDE__
#define __CAL_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

// Public Type Definitions ---------------------------------------------------------------------------------------------

typedef struct __attribute__((packed))
{
	u16 build;
	u8 minor;
	u8 major;
} Version_s;

typedef struct __attribute__((packed))
{
	char strDelimiter[12];
	Version_s version;
	float cmvTempDN0;
	float cmvTempT0;
} FactoryHeader_s;

// Public Function Prototypes ------------------------------------------------------------------------------------------

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern FactoryHeader_s * const factoryHeader;

#endif
