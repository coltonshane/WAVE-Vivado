/*
Calibration Module

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

// Include Headers -----------------------------------------------------------------------------------------------------

#include "main.h"
#include "cal.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define FACTORY_FLASH_BASE_ADDR 0xC0800000

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

FactoryHeader_s fhActive;

// Private Global Variables --------------------------------------------------------------------------------------------

FactoryHeader_s * const fhFlash = (FactoryHeader_s * const)(FACTORY_FLASH_BASE_ADDR);
FactoryHeader_s fhDefault = { .strDelimiter = "WAVE HELLO\n",
							  .version = {0, 0, 0},				// v0.0.0 indicates default cal
							  .cmvTempDN0 = 1860.0f,			// CMV12000 Datasheet Figure 3
							  .cmvTempT0 = 30.0f,				// CMV12000 Datasheet Figure 3
							  .cmvVtfl4K = (80 << 7) | 96,		// ~50% and ~75%
							  .cmvVtfl2K = (80 << 7) | 96 };	// ~50% and ~75%

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void calInit(void)
{
	if(strcmp(fhFlash->strDelimiter, "WAVE HELLO!\n") == 0)
	{
		// Factory header in flash is valid.
		memcpy(&fhActive, fhFlash, sizeof(FactoryHeader_s));
	}
	else
	{
		// Factory header in flash is invalid, use default cal.
		memcpy(&fhActive, &fhDefault, sizeof(FactoryHeader_s));
	}
}

// Private Function Definitions ----------------------------------------------------------------------------------------
