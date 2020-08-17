/*
HDMI 1D LUT Module

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
#include "hdmi_lut1d.h"
#include <math.h>

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Private Type Definitions --------------------------------------------------------------------------------------------

typedef struct __attribute__((packed))
{
	s16 R;
	s16 G;
	s16 B;
	s16 reserved;
} LUT1DColor_s; // [64B]

typedef struct __attribute__((packed))
{
	LUT1DColor_s lut1D_G1[4096];	// G1 10-bit input to 14-bit color mixer.
	LUT1DColor_s lut1D_R1[4096];	// R1 10-bit input to 14-bit color mixer.
	LUT1DColor_s lut1D_B1[4096];	// B1 10-bit input to 14-bit color mixer.
	LUT1DColor_s lut1D_G2[4096];	// G2 19-bit input to 14-bit color mixer.
	s16 lut1D_R[16384];				// R 14-bit curve.
	s16 lut1D_G[16384];				// G 14-bit curve.
	s16 lut1D_B[16384];				// B 14-bit curve.
	u8 reserved[32768];
} LUT1DPack_s; // [256KiB]

typedef enum
{
	HDR_DISABLED,
	HDR_ENABLED
} hdrStateType;

// Private Function Prototypes -----------------------------------------------------------------------------------------

void buildRGBMixerFromMatrix(LUT1DMatrix_s m, hdrStateType hdrState);
void buildRGBCurveFromGamma(float gamma, float x0, float m, float A);
void buildRGBCurveHDR();

LUT1DMatrix_s interpolateMatrix(LUT1DMatrix_s m0, LUT1DMatrix_s m1, float x);
float HDRtoLinear(double x);
float LineartoHDR(double y);

// Public Global Variables ---------------------------------------------------------------------------------------------

u32 * const lutG1 =      (u32 * const) 0xA0118000;
u32 * const lutR1 =      (u32 * const) 0xA0120000;
u32 * const lutB1 =      (u32 * const) 0xA0128000;
u32 * const lutG2 =      (u32 * const) 0xA0130000;
u32 * const lutR =       (u32 * const) 0xA0138000;
u32 * const lutG =       (u32 * const) 0xA0140000;
u32 * const lutB =       (u32 * const) 0xA0148000;

const LUT1DMatrix_s mIdentity = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};
const LUT1DMatrix_s mDummyTest = {1.5f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.5f};

// SC Calibration 8-9-2020
const LUT1DMatrix_s m5600K = { 1.79766f, -0.378569f, -0.134178f,
		  	  	  	  	  	  -0.261755f,   1.25f, -0.134178f,
							  -0.148242f, -0.721982f,  1.92007f };
const LUT1DMatrix_s m3200K = { 1.24495f, -0.288141f, -0.241375f,
		  	  	  	  	  	  -0.250881f,  1.25f, -0.491039f,
							  -0.0946473f, -0.814871f,  2.69544f };

LUT1DPack_s lut1dActive;

// Private Global Variables --------------------------------------------------------------------------------------------

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void hdmiLUT1DCreate(float colorTemp, hdmiLUT1DOETF_Type oetf)
{
	float x = (colorTemp - 3200.0f) / 2400.0f;
	LUT1DMatrix_s mColorTemp = interpolateMatrix(m3200K, m5600K, x);

	switch(oetf)
	{
	case HDMI_LUT1D_OETF_LINEAR:
		buildRGBMixerFromMatrix(mColorTemp, HDR_DISABLED);
		buildRGBCurveFromGamma(1.0f, 0.0f, 1.0f, 1.0f);
		break;
	case HDMI_LUT1D_OETF_REC709:
		buildRGBMixerFromMatrix(mColorTemp, HDR_DISABLED);
		buildRGBCurveFromGamma(1.0f / 0.45f, 0.018f, 4.5f, 1.099f);
		break;
	case HDMI_LUT1D_OETF_G18M3:
		buildRGBMixerFromMatrix(mColorTemp, HDR_DISABLED);
		buildRGBCurveFromGamma(1.8f, 0.025746f, 3.0f, 1.061793f);
		break;
	case HDMI_LUT1D_OETF_CMVHDR:
		buildRGBMixerFromMatrix(mColorTemp, HDR_ENABLED);
		buildRGBCurveHDR();
		break;
	}
}

void hdmiLUT1DIdentity(void)
{
	buildRGBMixerFromMatrix(mIdentity, HDR_DISABLED);
	buildRGBCurveFromGamma(1.0f, 0.0f, 1.0f, 1.0f);
}

void hdmiLUT1DApply(void)
{
	// RGB Color Mixer
	memcpy(lutG1, &lut1dActive.lut1D_G1[0], sizeof(LUT1DColor_s) * 4096);
	memcpy(lutR1, &lut1dActive.lut1D_R1[0], sizeof(LUT1DColor_s) * 4096);
	memcpy(lutB1, &lut1dActive.lut1D_B1[0], sizeof(LUT1DColor_s) * 4096);
	memcpy(lutG2, &lut1dActive.lut1D_G2[0], sizeof(LUT1DColor_s) * 4096);

	// RGB Curves
	memcpy(lutR, &lut1dActive.lut1D_R[0], sizeof(s16) * 16384);
	memcpy(lutG, &lut1dActive.lut1D_G[0], sizeof(s16) * 16384);
	memcpy(lutB, &lut1dActive.lut1D_B[0], sizeof(s16) * 16384);
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void buildRGBMixerFromMatrix(LUT1DMatrix_s m, hdrStateType hdrState)
{
	float fIn, fOut;
	LUT1DColor_s cOut;

	for(int cIn = 0; cIn < 4096; cIn++)
	{
		if(cIn < 1024)
		{ fIn = (float) cIn / 1024.0f; }	// In Range
		else if(cIn < 2048)
		{ fIn = 1.0f; }						// Clip High
		else
		{ fIn = 0.0f; }						// Clip Low

		if(hdrState == HDR_ENABLED)
		{ fIn = HDRtoLinear((double)fIn); }

		// G1/G2 to R
		fOut = (m.GtoR / 2.0f) * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.R = (s16)fOut;

		// G1/G2 to G
		fOut = (m.GtoG / 2.0f) * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.G = (s16)fOut;

		// G1/G2 to B
		fOut = (m.GtoB / 2.0f) * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.B = (s16)fOut;

		lut1dActive.lut1D_G1[cIn] = cOut;
		lut1dActive.lut1D_G2[cIn] = cOut;

		// R1 to R
		fOut = m.RtoR * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.R = (s16)fOut;

		// R1 to G
		fOut = m.RtoG * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.G = (s16)fOut;

		// R1 to B
		fOut = m.RtoB * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.B = (s16)fOut;

		lut1dActive.lut1D_R1[cIn] = cOut;

		// B1 to R
		fOut = m.BtoR * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.R = (s16)fOut;

		// B1 to G
		fOut = m.BtoG * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.G = (s16)fOut;

		// B1 to B
		fOut = m.BtoB * fIn * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }
		cOut.B = (s16)fOut;

		lut1dActive.lut1D_B1[cIn] = cOut;
	}
}

void buildRGBCurveFromGamma(float gamma, float x0, float m, float A)
{
	float fIn, fOut;

	for(int cIn = 0; cIn < 16384; cIn++)
	{
		fIn = cIn / 16384.0f;
		if(fIn < x0)
		{
			// Linear range below x0.
			fOut = m * fIn;
		}
		else
		{
			// Gamma range above x0.
			fOut = A * powf(fIn, 1.0f / gamma) - (A - 1.0f);
		}
		fOut *= 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }

		lut1dActive.lut1D_R[cIn] = (s16)fOut;
		lut1dActive.lut1D_G[cIn] = (s16)fOut;
		lut1dActive.lut1D_B[cIn] = (s16)fOut;
	}
}

void buildRGBCurveHDR(void)
{
	float fIn, fOut;

	for(int cIn = 0; cIn < 16384; cIn++)
	{
		fIn = cIn / 16384.0f;
		fOut = LineartoHDR((double)fIn) * 16384.0f;
		if(fOut > 16383.0f) { fOut = 16383.0f; }
		else if(fOut < 0.0f) { fOut = 0.0f; }

		lut1dActive.lut1D_R[cIn] = (s16)fOut;
		lut1dActive.lut1D_G[cIn] = (s16)fOut;
		lut1dActive.lut1D_B[cIn] = (s16)fOut;
	}
}

LUT1DMatrix_s interpolateMatrix(LUT1DMatrix_s m0, LUT1DMatrix_s m1, float x)
{
	LUT1DMatrix_s mOut;
	float * m0Element = (float *) &m0;
	float * m1Element = (float *) &m1;
	float * mOutElement = (float *) &mOut;

	for(int i = 0; i < 9; i++)
	{
		mOutElement[i] = (1.0f - x) * m0Element[i] + x * m1Element[i];
	}

	return mOut;
}

double debug_x_kp1 = 0.68;
double debug_x_win = 0.10;

float HDRtoLinear(double x)
{
	double y;

	double m0 = 0.0625;
	double x_kp1 = debug_x_kp1;
	double y_kp1 = m0 * x_kp1;
	double x_kp2 = 1.0;
	double y_kp2 = 0.5;

	double m1 = (y_kp2 - y_kp1) / (x_kp2 - x_kp1);

	double x_win = debug_x_win;
	double x0 = x_kp1 - x_win;
	double x1 = x_kp1 + x_win;
	double y0 = y_kp1 - m0 * x_win;
	double y1 = y_kp1 + m1 * x_win;

	double a, b, c;
	double den = (x0-x1)*(x0-x1)*(x0-x1);
	a = (-m0*(x0-x1)*(x0+2.0*x1)+m1*(-2.0*x0*x0+x1*x0+x1*x1)+3.0*(x0+x1)*(y0-y1))/den;
	b = (m1*x0*(x0-x1)*(x0+2.0*x1)-x1*(m0*(-2.0*x0*x0+x1*x0+x1*x1)+6.0*x0*(y0-y1)))/den;
	c = ((x0-3.0*x1)*y1*x0*x0+x1*(x0*(x1-x0)*(m1*x0+m0*x1)-x1*(x1-3.0*x0)*y0))/den;

	if(x < x0)
	{
		y = m0 * x;
	}
	else if(x < x1)
	{
		y = a * x * x + b * x + c;
	}
	else if(x < 1.0)
	{
		y = m1 * (x - x_kp1) + y_kp1;
	}
	else
	{
		y = 0.5;
	}

	return (float) y;
}

float LineartoHDR(double y)
{
	double x;

	double m0 = 0.0625;
	double x_kp1 = debug_x_kp1;
	double y_kp1 = m0 * x_kp1;
	double x_kp2 = 1.0;
	double y_kp2 = 0.5;

	double m1 = (y_kp2 - y_kp1) / (x_kp2 - x_kp1);

	double x_win = debug_x_win;
	double x0 = x_kp1 - x_win;
	double x1= x_kp1 + x_win;
	double y0 = y_kp1 - m0 * x_win;
	double y1 = y_kp1 + m1 * x_win;

	double a, b, c;
	double den = (x0-x1)*(x0-x1)*(x0-x1);
	a = (-m0*(x0-x1)*(x0+2.0*x1)+m1*(-2.0*x0*x0+x1*x0+x1*x1)+3.0*(x0+x1)*(y0-y1))/den;
	b = (m1*x0*(x0-x1)*(x0+2.0*x1)-x1*(m0*(-2.0*x0*x0+x1*x0+x1*x1)+6.0*x0*(y0-y1)))/den;
	c = ((x0-3.0*x1)*y1*x0*x0+x1*(x0*(x1-x0)*(m1*x0+m0*x1)-x1*(x1-3.0*x0)*y0))/den;

	double sqrt_operand = 0.0f;

	if(y < y0)
	{
		x = (1.0 / m0) * y;
	}
	else if(y < y1)
	{
		c = c - y;
		sqrt_operand = b*b-4.0*a*c;
		if(sqrt_operand < 0.0) { sqrt_operand = 0.0; }
		x = (-b+sqrt(sqrt_operand))/(2.0*a);
	}
	else if(y < 0.5)
	{
		x = (1.0 / m1) * (y - y_kp1) + x_kp1;
	}
	else
	{
		x = 1.0;
	}

	return (float) x;
}
