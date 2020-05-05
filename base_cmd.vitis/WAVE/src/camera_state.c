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

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

CameraState_s cState;
CameraSetting_s cSettingMode;
CameraSetting_s cSettingWidth;
CameraSetting_s cSettingHeight;
CameraSetting_s cSettingFPS;
CameraSetting_s cSettingShutter;
CameraSetting_s cSettingFormat;

char * cSettingModeName = "  MODE  ";
CameraSettingValue_s cSettingModeValArray[] = {{" STANDBY", 0.0f},
											   {"   REC  ", 1.0f},
											   {"PLAYBACK", 2.0f}};

char * cSettingWidthName = "  WIDTH ";
CameraSettingValue_s cSettingWidthValArray[] = {{"  4096 x", 4096.0f},
												{"  2048 x", 2048.0f}};

char * cSettingHeightName = " HEIGHT ";									// 	4K	2K
CameraSettingValue_s cSettingHeightValArray[] = {{"  3072p ", 3072.0f},	//	1x	No
												 {"  2304p ", 2304.0f},	//	1x	No
												 {"  2176p ", 2176.0f},	// 	1x	No
												 {"  2048p ", 2048.0f},	//	1x	No
												 {"  1760p ", 1760.0f},	//	1x	No
												 {"  1600p ", 1600.0f},	//	1x	No
												 {"  1536p ", 1536.0f},	//	2x	1x
												 {"  1440p ", 1440.0f},	//  2x	1x
												 {"  1280p ", 1280.0f},	//	2x	1x
												 {"  1152p ", 1152.0f},	//  2x	1x
												 {"  1120p ", 1120.0f},	//	2x	1x
												 {"  1088p ", 1088.0f},	//	2x	1x
												 {"  1024p ", 1024.0f},	//	3x	1x
												 {"   960p ", 960.0f},	//	3x	1x
												 {"   880p ", 880.0f},	//	3x	1x
												 {"   800p ", 800.0f},	//  3X  1x
												 {"   768p ", 768.0f},	//  4x  2x
												 {"   720p ", 720.0f},  //  4x  2x
												 {"   640p ", 640.0f},	//  4x  2x
												 {"   560p ", 560.0f},	//  5x  2x
												 {"   512p ", 512.0f},	//  6x  3x
												 {"   480p ", 480.0f},  //  6x  3x
												 {"   384p ", 384.0f},	//  8x	4x
												 {"   360p ", 360.0f},	//  8x  4x
												 {"   256p ", 256.0f},  // 12x  6x
												 {"   240p ", 240.0f},  // 12x  6x
												 {"   192p ", 192.0f},	// 16x  8x
												 {"   128p ", 128.0f}}; // 24x 12x

char * cSettingFPSName = "   FPS  ";
CameraSettingValue_s cSettingFPSValArray[] = {{" MAX fps", 0.0f},
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

char * cSettingFormatName = " FORMAT ";
CameraSettingValue_s cSettingFormatValArray[] = {{"Cancel  ", 0.0f},
												 {"Confirm ", 1.0f}};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void cameraStateInit(void)
{
	cSettingMode.id = 0;
	cSettingMode.val = 0;
	cSettingMode.count = 3;
	cSettingMode.enable[0] = 0x0000000000000005;
	cSettingMode.enable[1] = 0x0000000000000000;
	cSettingMode.enable[2] = 0x0000000000000000;
	cSettingMode.enable[3] = 0x0000000000000000;
	cSettingMode.strName = cSettingModeName;
	cSettingMode.valArray = cSettingModeValArray;
	cSettingMode.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL;

	cSettingWidth.id = 1;
	cSettingWidth.val = 0;
	cSettingWidth.count = 2;
	cSettingWidth.enable[0] = 0x0000000000000003;
	cSettingWidth.enable[1] = 0x0000000000000000;
	cSettingWidth.enable[2] = 0x0000000000000000;
	cSettingWidth.enable[3] = 0x0000000000000000;
	cSettingWidth.strName = cSettingWidthName;
	cSettingWidth.valArray = cSettingWidthValArray;
	cSettingWidth.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL;

	cSettingHeight.id = 2;
	cSettingHeight.val = 2;
	cSettingHeight.count = 28;
	cSettingHeight.enable[0] = 0x000000000000001F;
	cSettingHeight.enable[1] = 0x0000000000000000;
	cSettingHeight.enable[2] = 0x0000000000000000;
	cSettingHeight.enable[3] = 0x0000000000000000;
	cSettingHeight.strName = cSettingHeightName;
	cSettingHeight.valArray = cSettingHeightValArray;
	cSettingHeight.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL;

	cSettingFPS.id = 3;
	cSettingFPS.val = 1;
	cSettingFPS.count = 62;
	cSettingFPS.enable[0] = 0x000000007FFFFFFF;
	cSettingFPS.enable[1] = 0x0000000000000000;
	cSettingFPS.enable[2] = 0x0000000000000000;
	cSettingFPS.enable[3] = 0x0000000000000000;
	cSettingFPS.strName = cSettingFPSName;
	cSettingFPS.valArray = cSettingFPSValArray;
	cSettingFPS.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL;

	cSettingShutter.id = 4;
	cSettingShutter.val = 2;
	cSettingShutter.count = 19;
	cSettingShutter.enable[0] = 0x000000000007FFFF;
	cSettingShutter.enable[1] = 0x0000000000000000;
	cSettingShutter.enable[2] = 0x0000000000000000;
	cSettingShutter.enable[3] = 0x0000000000000000;
	cSettingShutter.strName = cSettingShutterName;
	cSettingShutter.valArray = cSettingShutterValArray;
	cSettingShutter.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_VAL;

	cSettingFormat.id = 5;
	cSettingFormat.val = 0;
	cSettingFormat.count = 2;
	cSettingFormat.enable[0] = 0x0000000000000003;
	cSettingFormat.enable[1] = 0x0000000000000000;
	cSettingFormat.enable[2] = 0x0000000000000000;
	cSettingFormat.enable[3] = 0x0000000000000000;
	cSettingFormat.strName = cSettingFormatName;
	cSettingFormat.valArray = cSettingFormatValArray;
	cSettingFormat.uiDisplayType = CSETTING_UI_DISPLAY_TYPE_NAME;

	cState.cSetting[0] = &cSettingMode;
	cState.cSetting[1] = &cSettingWidth;
	cState.cSetting[2] = &cSettingHeight;
	cState.cSetting[3] = &cSettingFPS;
	cState.cSetting[4] = &cSettingShutter;
	cState.cSetting[5] = &cSettingFormat;
}

u8 cameraStateSettingEnabled(u8 id, u8 val)
{
	u8 word = val / 64;
	u8 bit = val % 64;
	return ((cState.cSetting[id]->enable[word]) >> (bit)) & 0x1;
}

// Private Function Definitions ----------------------------------------------------------------------------------------
