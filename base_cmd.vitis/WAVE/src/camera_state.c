/*
WAVE State Machine

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
#include "camera_state.h"
#include "cmv12000.h"
#include "wavelet.h"
#include "encoder.h"
#include "frame.h"
#include "hdmi.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define CSETTING_HEIGHT_ENABLE_4K 0x000000000FFFFFFF
#define CSETTING_HEIGHT_ENABLE_2K 0x000000000FFFFFC0

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void cSettingModeSetVal(u8 val);
void cSettingWidthSetVal(u8 val);
void cSettingHeightSetVal(u8 val);
void cSettingFPSSetVal(u8 val);
void cSettingShutterSetVal(u8 val);
void cSettingColorSetVal(u8 val);
void cSettingFormatSetVal(u8 val);

void cSettingFPSPreviewVal(u8 val);
void cSettingShutterPreviewVal(u8 val);
void cSettingColorPreviewVal(u8 val);

void cSettingDoNothing(u8 val);

void cSettingSetEnabled(u8 id, u8 val, u8 en);

float cStateGetMaxFPS(void);

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

CameraState_s cState;
CameraSetting_s cSettingMode;
CameraSetting_s cSettingWidth;
CameraSetting_s cSettingHeight;
CameraSetting_s cSettingFPS;
CameraSetting_s cSettingShutter;
CameraSetting_s cSettingColor;
CameraSetting_s cSettingFormat;

char * cSettingModeName = "  MODE  ";
char * cSettingModeValFormat = " %6d ";
CameraSettingValue_s cSettingModeValArray[] = {{" STANDBY", 0.0f},
											   {"   REC  ", 1.0f},
											   {"PLAYBACK", 2.0f}};

char * cSettingWidthName = "  WIDTH ";
char * cSettingWidthValFormat = "  %4d x";
CameraSettingValue_s cSettingWidthValArray[] = {{"  4096 x", 4096.0f},
												{"  2048 x", 2048.0f}};

char * cSettingHeightName = " HEIGHT ";
char * cSettingHeightValFormat = "%6dp ";								// 	4K	2K
CameraSettingValue_s cSettingHeightValArray[] = {{"  3072p ", 3072.0f},	//	1x	No
												 {"  2304p ", 2304.0f},	//	1x	No
												 {"  2176p ", 2176.0f},	//	1x	No
												 {"  2048p ", 2048.0f},	//	1x	No
												 {"  1920p ", 1920.0f},	//	1x	No
												 {"  1792p ", 1792.0f},	//	1x	No
												 {"  1664p ", 1664.0f},	//	1x	No
												 {"  1536p ", 1536.0f},	//	2x	1x
												 {"  1408p ", 1408.0f},	//	2x	1x
												 {"  1280p ", 1280.0f},	//	2x	1x
												 {"  1152p ", 1152.0f},	//	2x	1x
												 {"  1088p ", 1088.0f},	//	2x	1x
												 {"  1024p ", 1024.0f},	//	3x	1x
												 {"   960p ", 960.0f},	//	3x	1x
												 {"   896p ", 896.0f},	//	3x	1x
												 {"   832p ", 832.0f},	//	3x	1x
												 {"   768p ", 768.0f},	//	4x	2x
												 {"   704p ", 704.0f},  //	4x	2x
												 {"   640p ", 640.0f},	//	4x	2x
												 {"   576p ", 576.0f},	//	5x	2x
												 {"   512p ", 512.0f},	//	6x	3x
												 {"   448p ", 448.0f},  //	6x	3x
												 {"   384p ", 384.0f},	//	8x	4x
												 {"   320p ", 320.0f},	//	9x	4x
												 {"   256p ", 256.0f},  // 12x	6x
												 {"   192p ", 192.0f},	// 16x	8x
												 {"   128p ", 128.0f}}; // 24x 12x

char * cSettingFPSName = "   FPS  ";
char * cSettingFPSValFormat = "%4d fps";
CameraSettingValue_s cSettingFPSValArray[] = {{"USER fps", 200.0f},
											  {" MAX fps", 422.0f},
											  {"  24 fps", 24.0f},
											  {"  25 fps", 25.0f},
											  {"  30 fps", 30.0f},
											  {"  48 fps", 48.0f},
											  {"  50 fps", 50.0f},
											  {"  60 fps", 60.0f},
											  {"  72 fps", 72.0f},
											  {"  90 fps", 90.0f},
											  {"  96 fps", 96.0f},
											  {" 120 fps", 120.0f},
											  {" 144 fps", 144.0f},
											  {" 150 fps", 150.0f},
											  {" 168 fps", 168.0f},
											  {" 180 fps", 180.0f},
											  {" 192 fps", 192.0f},
											  {" 210 fps", 210.0f},
											  {" 216 fps", 216.0f},
											  {" 240 fps", 240.0f},
											  {" 264 fps", 264.0f},
											  {" 270 fps", 270.0f},
											  {" 288 fps", 288.0f},
											  {" 300 fps", 300.0f},
											  {" 312 fps", 312.0f},
											  {" 330 fps", 330.0f},
											  {" 336 fps", 336.0f},
											  {" 360 fps", 360.0f},
											  {" 384 fps", 384.0f},
											  {" 390 fps", 390.0f},
											  {" 408 fps", 408.0f},
											  {" 420 fps", 420.0f},
											  {" 480 fps", 480.0f},
											  {" 600 fps", 600.0f},
											  {" 720 fps", 720.0f},
											  {" 840 fps", 840.0f},
											  {" 960 fps", 960.0f},
											  {"1080 fps", 1080.0f},
											  {"1200 fps", 1200.0f},
											  {"1320 fps", 1320.0f},
											  {"1440 fps", 1440.0f},
											  {"1680 fps", 1680.0f},
											  {"1920 fps", 1920.0f},
											  {"2160 fps", 2160.0f},
											  {"2400 fps", 2400.0f},
											  {"2640 fps", 2640.0f},
											  {"2880 fps", 2880.0f},
											  {"3120 fps", 3120.0f},
											  {"3360 fps", 3360.0f},
											  {"3600 fps", 3600.0f},
											  {"3840 fps", 3840.0f},
											  {"4320 fps", 4320.0f},
											  {"4800 fps", 4800.0f},
											  {"5280 fps", 5280.0f},
											  {"5760 fps", 5760.0f},
											  {"6240 fps", 6240.0f},
											  {"6720 fps", 6720.0f},
											  {"7200 fps", 7200.0f},
											  {"7680 fps", 7680.0f},
											  {"8160 fps", 8160.0f},
											  {"8640 fps", 8640.0f},
											  {"9120 fps", 9120.0f},
											  {"9600 fps", 9600.0f}};

char * cSettingShutterName = " SHUTTER";
char * cSettingShutterValFormat = " %6d ";
CameraSettingValue_s cSettingShutterValArray[] = {{"   360* ", 360.0f},				// +1
												  {"   270* ", 270.0f},
												  {"   180* ", 180.0f},				//  0
												  {"   135* ", 135.0f},
												  {"    90* ", 90.0f},				// -1
												  {"  63.6* ", 63.63961030678927f},
												  {"    45* ", 45.0f},				// -2
												  {"  31.8* ", 31.81980515339463f},
												  {"  22.5* ", 22.5f},				// -3
												  {"  15.9* ", 15.909902576697313f},
												  {"  11.3* ", 11.25f},				// -4
												  {"  7.96* ", 7.9549512883486555f},
												  {"  5.63* ", 5.625f},				// -5
												  {"  3.98* ", 3.9774756441743278f},
												  {"  2.81* ", 2.8125f},			// -6
												  {"  1.99* ", 1.9887378220871634f},
												  {"  1.41* ", 1.40625f},			// -7
												  {"  0.99* ", 0.9943689110435816f},
												  {"  0.70* ", 0.703125f}}; 		// -8

char * cSettingColorName = "  COLOR ";
char * cSettingColorValFormat = " %6d ";
CameraSettingValue_s cSettingColorValArray[] = {{"  2000K ", 2000.0f},
												{"  2400K ", 2400.0f},
												{"  2800K ", 2800.0f},
												{"  3200K ", 3200.0f},
												{"  3600K ", 3600.0f},
												{"  4000K ", 4000.0f},
												{"  4400K ", 4400.0f},
												{"  4800K ", 4800.0f},
												{"  5200K ", 5200.0f},
												{"  5600K ", 5600.0f},
												{"  6000K ", 6000.0f},
												{"  6400K ", 6400.0f},
												{"  6800K ", 6800.0f},
												{"  7200K ", 7200.0f},
												{"  7600K ", 7600.0f},
												{"  8000K ", 8000.0f},
												{"  8400K ", 8400.0f},
												{"  8800K ", 8800.0f},
												{"  9200K ", 9200.0f},
												{"  9600K ", 9600.0f}};

char * cSettingFormatName = " FORMAT ";
char * cSettingFormatValFormat = " %6d ";
CameraSettingValue_s cSettingFormatValArray[] = {{"Cancel  ", 0.0f},
												 {"Confirm ", 1.0f}};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void cStateInit(void)
{
	cSettingMode.id = 0;
	cSettingMode.val = 0;
	cSettingMode.count = 3;
	cSettingMode.enable[0] = 0x0000000000000005;
	cSettingMode.enable[1] = 0x0000000000000000;
	cSettingMode.enable[2] = 0x0000000000000000;
	cSettingMode.enable[3] = 0x0000000000000000;
	cSettingMode.user[0] = 0x0000000000000000;
	cSettingMode.user[1] = 0x0000000000000000;
	cSettingMode.user[2] = 0x0000000000000000;
	cSettingMode.user[3] = 0x0000000000000000;
	cSettingMode.strName = cSettingModeName;
	cSettingMode.strValFormat = cSettingModeValFormat;
	cSettingMode.valArray = cSettingModeValArray;
	cSettingMode.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL_ARRAY;
	cSettingMode.SetVal = &cSettingModeSetVal;
	cSettingMode.PreviewVal = &cSettingDoNothing;

	cSettingWidth.id = 1;
	cSettingWidth.val = 0;
	cSettingWidth.count = 2;
	cSettingWidth.enable[0] = 0x0000000000000003;
	cSettingWidth.enable[1] = 0x0000000000000000;
	cSettingWidth.enable[2] = 0x0000000000000000;
	cSettingWidth.enable[3] = 0x0000000000000000;
	cSettingWidth.user[0] = 0x0000000000000000;
	cSettingWidth.user[1] = 0x0000000000000000;
	cSettingWidth.user[2] = 0x0000000000000000;
	cSettingWidth.user[3] = 0x0000000000000000;
	cSettingWidth.strName = cSettingWidthName;
	cSettingWidth.strValFormat = cSettingWidthValFormat;
	cSettingWidth.valArray = cSettingWidthValArray;
	cSettingWidth.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL_ARRAY;
	cSettingWidth.SetVal = &cSettingWidthSetVal;
	cSettingWidth.PreviewVal = &cSettingDoNothing;

	cSettingHeight.id = 2;
	cSettingHeight.val = 2;
	cSettingHeight.count = 27;
	cSettingHeight.enable[0] = CSETTING_HEIGHT_ENABLE_4K;
	cSettingHeight.enable[1] = 0x0000000000000000;
	cSettingHeight.enable[2] = 0x0000000000000000;
	cSettingHeight.enable[3] = 0x0000000000000000;
	cSettingHeight.user[0] = 0x0000000000000000;
	cSettingHeight.user[1] = 0x0000000000000000;
	cSettingHeight.user[2] = 0x0000000000000000;
	cSettingHeight.user[3] = 0x0000000000000000;
	cSettingHeight.strName = cSettingHeightName;
	cSettingHeight.strValFormat = cSettingHeightValFormat;
	cSettingHeight.valArray = cSettingHeightValArray;
	cSettingHeight.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL_FORMAT_INT;
	cSettingHeight.SetVal = &cSettingHeightSetVal;
	cSettingHeight.PreviewVal = &cSettingDoNothing;

	cSettingFPS.id = 3;
	cSettingFPS.val = 2;
	cSettingFPS.count = 63;
	cSettingFPS.enable[0] = 0x7FFFFFFFFFFFFFFF;
	cSettingFPS.enable[1] = 0x0000000000000000;
	cSettingFPS.enable[2] = 0x0000000000000000;
	cSettingFPS.enable[3] = 0x0000000000000000;
	cSettingFPS.user[0] = 0x0000000000000001;
	cSettingFPS.user[1] = 0x0000000000000000;
	cSettingFPS.user[2] = 0x0000000000000000;
	cSettingFPS.user[3] = 0x0000000000000000;
	cSettingFPS.strName = cSettingFPSName;
	cSettingFPS.strValFormat = cSettingFPSValFormat;
	cSettingFPS.valArray = cSettingFPSValArray;
	cSettingFPS.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL_FORMAT_INT;
	cSettingFPS.SetVal = &cSettingFPSSetVal;
	cSettingFPS.PreviewVal = &cSettingFPSPreviewVal;

	cSettingShutter.id = 4;
	cSettingShutter.val = 2;
	cSettingShutter.count = 19;
	cSettingShutter.enable[0] = 0x000000000007FFFF;
	cSettingShutter.enable[1] = 0x0000000000000000;
	cSettingShutter.enable[2] = 0x0000000000000000;
	cSettingShutter.enable[3] = 0x0000000000000000;
	cSettingShutter.user[0] = 0x0000000000000000;
	cSettingShutter.user[1] = 0x0000000000000000;
	cSettingShutter.user[2] = 0x0000000000000000;
	cSettingShutter.user[3] = 0x0000000000000000;
	cSettingShutter.strName = cSettingShutterName;
	cSettingShutter.strValFormat = cSettingShutterValFormat;
	cSettingShutter.valArray = cSettingShutterValArray;
	cSettingShutter.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL_ARRAY;
	cSettingShutter.SetVal = &cSettingShutterSetVal;
	cSettingShutter.PreviewVal = &cSettingShutterPreviewVal;

	cSettingColor.id = 5;
	cSettingColor.val = 9;
	cSettingColor.count = 20;
	cSettingColor.enable[0] = 0x00000000000FFFFF;
	cSettingColor.enable[1] = 0x0000000000000000;
	cSettingColor.enable[2] = 0x0000000000000000;
	cSettingColor.enable[3] = 0x0000000000000000;
	cSettingColor.user[0] = 0x0000000000000000;
	cSettingColor.user[1] = 0x0000000000000000;
	cSettingColor.user[2] = 0x0000000000000000;
	cSettingColor.user[3] = 0x0000000000000000;
	cSettingColor.strName = cSettingColorName;
	cSettingColor.strValFormat = cSettingColorValFormat;
	cSettingColor.valArray = cSettingColorValArray;
	cSettingColor.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL_ARRAY;
	cSettingColor.SetVal = &cSettingColorSetVal;
	cSettingColor.PreviewVal = &cSettingColorPreviewVal;

	cSettingFormat.id = 6;
	cSettingFormat.val = 0;
	cSettingFormat.count = 2;
	cSettingFormat.enable[0] = 0x0000000000000003;
	cSettingFormat.enable[1] = 0x0000000000000000;
	cSettingFormat.enable[2] = 0x0000000000000000;
	cSettingFormat.enable[3] = 0x0000000000000000;
	cSettingFormat.user[0] = 0x0000000000000000;
	cSettingFormat.user[1] = 0x0000000000000000;
	cSettingFormat.user[2] = 0x0000000000000000;
	cSettingFormat.user[3] = 0x0000000000000000;
	cSettingFormat.strName = cSettingFormatName;
	cSettingFormat.strValFormat = cSettingFormatValFormat;
	cSettingFormat.valArray = cSettingFormatValArray;
	cSettingFormat.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_NAME;
	cSettingFormat.SetVal = &cSettingFormatSetVal;
	cSettingFormat.PreviewVal = &cSettingDoNothing;

	cState.cSetting[0] = &cSettingMode;
	cState.cSetting[1] = &cSettingWidth;
	cState.cSetting[2] = &cSettingHeight;
	cState.cSetting[3] = &cSettingFPS;
	cState.cSetting[4] = &cSettingShutter;
	cState.cSetting[5] = &cSettingColor;
	cState.cSetting[6] = &cSettingFormat;

	// Manually trigger cSettingWidthSetVal() to make sure initial state is applied.
	cSettingWidthSetVal(CSETTING_WIDTH_4K);
}

void cStateApply(void)
{
	cmvApplyCameraState();
	waveletApplyCameraState();
	encoderApplyCameraState();
	frameApplyCameraState();
	hdmiApplyCameraState();
}

u8 cSettingGetEnabled(u8 id, u8 val)
{
	u8 word = val / 64;
	u8 bit = val % 64;
	return ((cState.cSetting[id]->enable[word]) >> bit) & 0x1;
}

void cSettingSetEnabled(u8 id, u8 val, u8 en)
{
	u8 word = val / 64;
	u8 bit = val % 64;
	if(en) { cState.cSetting[id]->enable[word] |= ((u64)1 << bit); }
	else { cState.cSetting[id]->enable[word] &= ~ ((u64)1 << bit); }
}

u8 cSettingGetUser(u8 id, u8 val)
{
	u8 word = val / 64;
	u8 bit = val % 64;
	return ((cState.cSetting[id]->user[word]) >> bit) & 0x1;
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void cSettingModeSetVal(u8 val)
{
	switch(cSettingMode.val)
	{
	case CSETTING_MODE_STANDBY:
		if(val == CSETTING_MODE_REC)
		{
			// Start a new clip.
			frameCreateClip();
			cSettingMode.val = CSETTING_MODE_REC;
		}
		break;
	case CSETTING_MODE_REC:
		if(val == CSETTING_MODE_STANDBY)
		{
			// End clip.
			frameCloseClip();
			cSettingMode.val = CSETTING_MODE_STANDBY;
		}
		break;
	}
}

void cSettingWidthSetVal(u8 val)
{
	float newHeightTarget;
	u8 newHeight;

	if(!cSettingGetEnabled(CSETTING_WIDTH, val)) { return; }

	// Enable/disable valid heights.
	if(val == CSETTING_WIDTH_4K)
	{ cSettingHeight.enable[0] = CSETTING_HEIGHT_ENABLE_4K; }
	else
	{ cSettingHeight.enable[0] = CSETTING_HEIGHT_ENABLE_2K; }

	// When switching between 2K and 4K, preserve aspect ratio if possible.
	newHeightTarget = cSettingHeight.valArray[cSettingHeight.val].fVal;
	newHeightTarget *= cSettingWidth.valArray[val].fVal / cSettingWidth.valArray[cSettingWidth.val].fVal;
	newHeight = cSettingHeight.count - 1;	// If no height is small enough, use the smallest.
	for(u8 i = 0; i < cSettingHeight.count; i++)
	{
		if((cSettingHeight.valArray[i].fVal <= newHeightTarget)
		&& (cSettingGetEnabled(CSETTING_HEIGHT, i)))
		{
			// Accept the first height that is enabled and less than or equal to the target.
			newHeight = i;
			break;
		}
	}

	// Change the width.
	cSettingWidth.val = val;

	// Change the height. Always called after changing widths so that max FPS is updated.
	cSettingHeightSetVal(newHeight);
}

void cSettingHeightSetVal(u8 val)
{
	float maxFPS;

	if(!cSettingGetEnabled(CSETTING_HEIGHT, val)) { return; }

	// Change the height.
	cSettingHeight.val = val;

	// Enable/disable the static FPS values according to the new height.
	maxFPS = cStateGetMaxFPS();
	for(u8 i = 2; i < cSettingFPS.count; i++)
	{
		if(cSettingFPS.valArray[i].fVal <= maxFPS)
		{ cSettingSetEnabled(CSETTING_FPS, i, 1); }
		else
		{ cSettingSetEnabled(CSETTING_FPS, i, 0); }
	}

	// Set the MAX FPS value.
	cSettingFPS.valArray[CSETTING_FPS_MAX].fVal = (float)((int)maxFPS);

	// Limit the USER FPS value.
	if(cSettingFPS.valArray[CSETTING_FPS_USER].fVal > maxFPS)
	{ cSettingFPS.valArray[CSETTING_FPS_USER].fVal = (float)((int)maxFPS); }
	if(cSettingFPS.valArray[CSETTING_FPS_USER].fVal < 1.0f)
	{ cSettingFPS.valArray[CSETTING_FPS_USER].fVal = 1.0f; }

	// If the current FPS value is too high, set it to MAX.
	if(cSettingFPS.valArray[cSettingFPS.val].fVal > maxFPS)
	{ cSettingFPSSetVal(CSETTING_FPS_MAX); }
}

void cSettingFPSSetVal(u8 val)
{
	if(!cSettingGetEnabled(CSETTING_FPS, val)) { return; }

	// Change the frame rate.
	cSettingFPS.val = val;
}

void cSettingShutterSetVal(u8 val)
{
	if(!cSettingGetEnabled(CSETTING_SHUTTER, val)) { return; }

	// Change the shutter angle.
	cSettingShutter.val = val;
}

void cSettingColorSetVal(u8 val)
{
	if(!cSettingGetEnabled(CSETTING_COLOR, val)) { return; }

	// Change the color temperature.
	cSettingColor.val = val;
}

void cSettingFormatSetVal(u8 val)
{
	if(!cSettingGetEnabled(CSETTING_FORMAT, val)) { return; }

	// Format.
	cSettingFormat.val = val;
}

void cSettingFPSPreviewVal(u8 val)
{
	float maxFPS;

	if(!cSettingGetEnabled(CSETTING_FPS, val)) { return; }

	// If previewing USER fps, limit range to 1 fps - MAX fps.
	if(val == CSETTING_FPS_USER)
	{
		maxFPS = cStateGetMaxFPS();
		if(cSettingFPS.valArray[CSETTING_FPS_USER].fVal > maxFPS)
		{ cSettingFPS.valArray[CSETTING_FPS_USER].fVal = (float)((int)maxFPS); }
		if(cSettingFPS.valArray[CSETTING_FPS_USER].fVal < 1.0f)
		{ cSettingFPS.valArray[CSETTING_FPS_USER].fVal = 1.0f; }
	}

	// Change the frame rate and immediately apply it to the CMV_Input module.
	cSettingFPS.val = val;
	cmvApplyCameraState();
}

void cSettingShutterPreviewVal(u8 val)
{
	if(!cSettingGetEnabled(CSETTING_SHUTTER, val)) { return; }

	// Change the shutter angle and immediately apply it to the CMV_Input module.
	cSettingShutter.val = val;
	cmvApplyCameraState();
}

void cSettingColorPreviewVal(u8 val)
{
	if(!cSettingGetEnabled(CSETTING_COLOR, val)) { return; }

	// Change the color temperature and immediately apply it to the HDMI module.
	cSettingColor.val = val;
	hdmiApplyCameraState();
}

void cSettingDoNothing(u8 val)
{
	return;
}

// Calculate the maximum FPS according to the CMV12000 datasheet.
float cStateGetMaxFPS(void)
{
	float fPixel = 60E6f;
	u8 r82msb, r85;
	float hMult;
	float tLine, tFOT, tFrame;
	float fFrame;

	if(cSettingWidth.valArray[cSettingWidth.val].fVal == 4096.0f)
	{
		r82msb = 12;
		r85 = 128;
		hMult = 0.5f;	// Reading in two rows in parallel.
	}
	else
	{
		r82msb = 11;
		r85 = 143;
		hMult = 0.25f;	// Reading in four rows in parallel.
	}

	tLine = (float)(r85 + 1) / fPixel;
	tFOT = (float)(r82msb + 2) * tLine;
	tFrame = tFOT + hMult * tLine * cSettingHeight.valArray[cSettingHeight.val].fVal;
	fFrame = 1.0f / tFrame;

	return fFrame;
}
