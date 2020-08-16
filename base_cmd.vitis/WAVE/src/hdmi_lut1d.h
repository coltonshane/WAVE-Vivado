/*
HDMI 1D LUT Include

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

#ifndef __HDMI_LUT1D_INCLUDE__
#define __HDMI_LUT1D_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

// Public Type Definitions ---------------------------------------------------------------------------------------------

typedef struct __attribute__((packed))
{
	float RtoR;
	float GtoR;
	float BtoR;
	float RtoG;
	float GtoG;
	float BtoG;
	float RtoB;
	float GtoB;
	float BtoB;
} LUT1DMatrix_s;

typedef enum
{
	HDMI_LUT1D_OETF_LINEAR,
	HDMI_LUT1D_OETF_REC709,
	HDMI_LUT1D_OETF_G18M3,
	HDMI_LUT1D_OETF_CMVHDR,
} hdmiLUT1DOETF_Type;

// Public Function Prototypes ------------------------------------------------------------------------------------------

// Build a LUT1D Pack in RAM from parameters.
void hdmiLUT1DCreate(float colorTemp, hdmiLUT1DOETF_Type oetf);

// Build an identity LUT1D Pack in RAM.
void hdmiLUT1DIdentity(void);

// Apply the active LUT1D Pack in RAM to the HDMI peripheral LUT1D URAMs.
void hdmiLUT1DApply(void);

// Externed Public Global Variables ------------------------------------------------------------------------------------

extern const LUT1DMatrix_s m5600K;
extern const LUT1DMatrix_s m3200K;

#endif
