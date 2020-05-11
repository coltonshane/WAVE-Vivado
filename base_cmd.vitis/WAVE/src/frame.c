/*
WAVE Frame Management

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

#include "main.h"
#include "frame.h"
#include "gpio.h"
#include "cmv12000.h"
#include "encoder.h"
#include "fs.h"
#include "nvme.h"
#include "xtime_l.h"
#include "camera_state.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define FH_BUFFER_SIZE 4096		// 2MiB: 0x18000000 - 0x18200000
#define FRAME_LB_EXP 9

#define US_PER_COUNT 1000 / (COUNTS_PER_SECOND / 1000)

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void frameApplyCameraStateSync(void);
void frameRecord(void);
void frameUpdateTemps(void);

// Public Global Variables ---------------------------------------------------------------------------------------------

// Frame header circular buffer in external DDR4 RAM.
FrameHeader_s * fhBuffer = (FrameHeader_s *) (0x18000000);

// Private Global Variables --------------------------------------------------------------------------------------------

u32 nSubFramesIn = 0xFFFFFFFF;
s32 nFramesIn = -1;
s32 nFramesOutStart = 0;
s32 nFramesOut = 0;

u32 frameApplyCameraStateSyncFlag = 0;
u32 nFramesPerFile = 481;
u32 nSubframesPerFrame = 1;

u8 frameTempPS = 0x00;
u8 frameTempPL = 0x00;
u8 frameTempCMV = 0x00;
u8 frameTempSSD = 0x00;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

/*
Frame Overhead Time (FOT) Interrupt Service Routine
- Interrupt flag set by rising edge of FOT bit signal on the CMV12000 control channel.
- Interrupt flag cleared by software.
- Constructs frame headers in an external DDR4 buffer. DDR4 access does not compete with frame read-in if
  the ISR returns before the end of the FOT period, which lasts about 20-30us.
*/
void isrFOT(void * CallbackRef)
{
	Encoder_s Encoder_prev, Encoder_next;
	XTime tFrameIn;
	u32 iFrameIn;

	nSubFramesIn++;
	CMV_Input->FOT_int = 0x00000000;			// Clear the FOT interrupt flag.

	if(nSubFramesIn % nSubframesPerFrame > 0) { return; }

	XGpioPs_WritePin(&Gpio, GPIO1_PIN, 1);		// Mark ISR entry.

	// Time-critical Encoder access. Must complete before end of FOT.
	memcpy(&Encoder_prev, Encoder, sizeof(Encoder_s));
	encoderServiceRAMAddr(&Encoder_prev);
	memcpy(&Encoder_next, Encoder, sizeof(Encoder_s));
	XGpioPs_WritePin(&Gpio, T_EXP1_PIN, 0);

	// Record information for the just-captured frame (if one exists).
	if(nFramesIn >= 0)
	{
		iFrameIn = nFramesIn % FH_BUFFER_SIZE;
		for(int iCS = 0; iCS < 16; iCS++)
		{
			// Codestream size.
			fhBuffer[iFrameIn].csSize[iCS] = Encoder_prev.c_RAM_addr[iCS] - fhBuffer[iFrameIn].csAddr[iCS];
		}
	}

	// Increment the input frame counter.
	nFramesIn++;
	iFrameIn = nFramesIn % FH_BUFFER_SIZE;

	// Wipe old data.
	memset(&fhBuffer[iFrameIn], 0, 512);

	// Time and index stamp the upcoming frame.
	XTime_GetTime(&tFrameIn);
	fhBuffer[iFrameIn].tFrameRead_us = tFrameIn * US_PER_COUNT;
	fhBuffer[iFrameIn].nFrame = nFramesIn;

	// Frame delimeter and info for the upcoming frame.
	memcpy(fhBuffer[iFrameIn].delimeter, "WAVE HELLO!\n",12);
	fhBuffer[iFrameIn].wFrame = (u16)(cState.cSetting[CSETTING_WIDTH]->valArray[cState.cSetting[CSETTING_WIDTH]->val].fVal);
	fhBuffer[iFrameIn].hFrame = (u16)(cState.cSetting[CSETTING_HEIGHT]->valArray[cState.cSetting[CSETTING_HEIGHT]->val].fVal);;
	fhBuffer[iFrameIn].tExp = cmvGetExposure();

	// Quantizer settings for the upcoming frame.
	// TO-DO: Right here is where the quantizer settings should be modified to hit bit rate target!
	fhBuffer[iFrameIn].q_mult_HH1_HL1_LH1 = Encoder_next.q_mult_HH1_HL1_LH1;
	fhBuffer[iFrameIn].q_mult_HH2_HL2_LH2 = Encoder_next.q_mult_HH2_HL2_LH2;

	// Codestream start addresses and FIFO state for the upcoming frame.
	fhBuffer[iFrameIn].csFIFOFlags = Encoder_next.fifo_flags;
	for(int iCS = 0; iCS < 16; iCS++)
	{
		fhBuffer[iFrameIn].csAddr[iCS] = Encoder_next.c_RAM_addr[iCS];
		fhBuffer[iFrameIn].csFIFOState[iCS] = Encoder_next.fifo_rd_count[iCS];
	}

	// Apply camera state settings to the frame module.
	if(frameApplyCameraStateSyncFlag)
	{
		frameApplyCameraStateSyncFlag = 0;
		frameApplyCameraStateSync();
	}

	XGpioPs_WritePin(&Gpio, GPIO1_PIN, 0);		// Mark ISR exit.
}

// Public Function Definitions -----------------------------------------------------------------------------------------

void frameInit(void)
{
	CMV_Input->FRAME_REQ_on = 0;
	frameApplyCameraStateSync();
}

void frameApplyCameraState(void)
{
	// Wait for next FOT to apply camera settings.
	frameApplyCameraStateSyncFlag = 1;
}

void frameCreateClip(void)
{
	fsCreateClip();

	// Start recording at the current frame.
	nFramesOutStart = nFramesIn;
	nFramesOut = nFramesOutStart;
}

void frameAddToClip(void)
{
	if(nFramesOut + 3 < nFramesIn) { frameRecord(); }
}

void frameCloseClip(void)
{
	fsCloseClip();
}

int frameLastCaptured(void)
{
	if(nFramesIn < 1) { return -1; }

	return (nFramesIn - 1) % FH_BUFFER_SIZE;
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void frameApplyCameraStateSync(void)
{
	float wFrame, hFrame;
	float h4x3;
	float szFrame;

	wFrame = cState.cSetting[CSETTING_WIDTH]->valArray[cState.cSetting[CSETTING_WIDTH]->val].fVal;
	hFrame = cState.cSetting[CSETTING_HEIGHT]->valArray[cState.cSetting[CSETTING_HEIGHT]->val].fVal;
	h4x3 = (wFrame == 4096.0f) ? 3072.0f : 1536.0f;

	// Set nSubframesPerFrame based on integer fill of 4x3 height.
	nSubframesPerFrame = (u32)(h4x3 / hFrame);

	// Set nFramesPerFile for roughly 1GiB files at 5:1 compression (2b/px = 0.25B/px).
	szFrame = (float)(nSubframesPerFrame) * wFrame * hFrame * 0.25f;
	nFramesPerFile = (u32)((float)(1 << 30) / szFrame);
}

void frameRecord(void)
{
	XTime tFrameOut;
	u32 iFrameOut;
	u32 csAddrBuffer[16];
	u32 csSizeBuffer[16];

	// XGpioPs_WritePin(&Gpio, GPIO2_PIN, 1);		// Mark frame recorder entry.

	// Fill in write-time frame header data.
	XTime_GetTime(&tFrameOut);
	iFrameOut = nFramesOut % FH_BUFFER_SIZE;
	fhBuffer[iFrameOut].nFrameBacklog = nFramesIn - nFramesOut;
	fhBuffer[iFrameOut].tFrameWrite_us = tFrameOut * US_PER_COUNT;

	// Fill in temperature sensor data.
	fhBuffer[iFrameOut].tempPS = frameTempPS;
	fhBuffer[iFrameOut].tempPL = frameTempPL;
	fhBuffer[iFrameOut].tempCMV = frameTempCMV;
	fhBuffer[iFrameOut].tempSSD = frameTempSSD;

	// Copy the codestream addresses and sizes once to minimize DDR access.
	memcpy(csAddrBuffer, fhBuffer[iFrameOut].csAddr, 16 * sizeof(u32));
	memcpy(csSizeBuffer, fhBuffer[iFrameOut].csSize, 16 * sizeof(u32));

	if(((nFramesOut - nFramesOutStart) % nFramesPerFile) == 0)
	{
		nvmeGetMetrics();	// Sample SSD metrics (incl. temperature).
		frameUpdateTemps();	// Update temperature sensor frame header-logged values.
		fsCreateFile();		// Create a new file in the clip.
	}

	// Write frame header.
	fsWriteFile((u64)(&fhBuffer[iFrameOut]), 512);

	// Write codestream data.
	for(int iCS = 0; iCS < 16; iCS++)
	{
		fsWriteFile((u64) csAddrBuffer[iCS], csSizeBuffer[iCS]);
	}

	nFramesOut++;

	// XGpioPs_WritePin(&Gpio, GPIO2_PIN, 0);		// Mark frame recorder exit.
}

void frameUpdateTemps(void)
{
	frameTempPS = (u8)(psplGetTemp(psTemp) + 100.0f);
	frameTempPL = (u8)(psplGetTemp(plTemp) + 100.0f);
	frameTempCMV = (u8)(cmvGetTemp() + 100.0f);
	frameTempSSD = (u8)(nvmeGetTemp() + 100.0f);
}

