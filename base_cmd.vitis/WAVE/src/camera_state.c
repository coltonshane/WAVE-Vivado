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

char * cSettingModeName =   	 "  MODE  ";
char * cSettingModeValArray[] = {" STANDBY",
								 "   REC  ",
								 "PLAYBACK"};

char * cSettingWidthName = 	 	  "  WIDTH ";
char * cSettingWidthValArray[] = {"  4096 x",
								  "  2048 x"};

char * cSettingHeightName =  	   " HEIGHT ";	// 	4K	2K
char * cSettingHeightValArray[] = {"  3072p ",	//	1x	No
								   "  2304p ",	//	1x	No
								   "  2176p ",	// 	1x	No
								   "  2048p ",	//	1x	No
								   "  1760p ",	//	1x	No
								   "  1600p ",	//	1x	No
								   "  1536p ",	//	2x	1x
								   "  1440p ",	//  2x	1x
								   "  1280p ",	//	2x	1x
								   "  1152p ",	//  2x	1x
								   "  1120p ",	//	2x	1x
								   "  1088p ",	//	2x	1x
								   "  1024p ",	//	3x	1x
								   "   960p ",	//	3x	1x
								   "   880p ",	//	3x	1x
								   "   800p ",	//  3X  1x
								   "   768p ",	//  4x  2x
								   "   720p ",  //  4x  2x
								   "   640p ",	//  4x  2x
								   "   560p ",	//  5x  2x
								   "   512p ",	//  6x  3x
								   "   480p ",  //  6x  3x
								   "   384p ",	//  8x	4x
								   "   360p ",	//  8x  4x
								   "   256p ",  // 12x  6x
								   "   240p ",  // 12x  6x
								   "   192p ",	// 16x  8x
								   "   128p "}; // 24x 12x

char * cSettingFPSName =         "   FPS  ";
char * cSettingFPSValArray[] = { " MAX fps",
								 "  24 fps",
								 "  25 fps",
								 "  30 fps",
								 "  48 fps",
								 "  50 fps",
								 "  60 fps",
								 "  72 fps",
								 "  90 fps",
								 "  96 fps",
								 " 120 fps",
								 " 144 fps",
								 " 150 fps",
								 " 168 fps",
								 " 180 fps",
								 " 192 fps",
								 " 210 fps",
								 " 216 fps",
								 " 240 fps",
								 " 264 fps",
								 " 270 fps",
								 " 288 fps",
								 " 300 fps",
								 " 312 fps",
								 " 330 fps",
								 " 336 fps",
								 " 360 fps",
								 " 384 fps",
								 " 390 fps",
								 " 408 fps",
								 " 420 fps",
								 " 480 fps",
								 " 600 fps",
								 " 720 fps",
								 " 840 fps",
								 " 960 fps",
								 "1080 fps",
								 "1200 fps",
								 "1320 fps",
								 "1440 fps",
								 "1680 fps",
								 "1920 fps",
								 "2160 fps",
								 "2400 fps",
								 "2640 fps",
								 "2880 fps",
								 "3120 fps",
								 "3360 fps",
								 "3600 fps",
								 "3840 fps",
								 "4320 fps",
								 "4800 fps",
								 "5280 fps",
								 "5760 fps",
								 "6240 fps",
								 "6720 fps",
								 "7200 fps",
								 "7680 fps",
								 "8160 fps",
								 "8640 fps",
								 "9120 fps",
								 "9600 fps" };

char * cSettingShutterName = " SHUTTER";
char * cSettingShutterValArray[] = { "   360* ",
									 "   270* ",
									 "   180* ",
									 "   135* ",
									 "    90* ",
									 "  63.6* ",
									 "    45* ",
									 "  31.8* ",
									 "  22.5* ",
									 "  15.9* ",
									 "  11.3* ",
									 "  7.96* ",
									 "  5.63* ",
									 "  3.98* ",
									 "  2.81* ",
									 "  1.99* ",
									 "  1.41* ",
									 "  0.99* ",
									 "  0.70* " };

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
	cSettingMode.strValArray = cSettingModeValArray;

	cSettingWidth.id = 1;
	cSettingWidth.val = 0;
	cSettingWidth.count = 2;
	cSettingWidth.enable[0] = 0x0000000000000003;
	cSettingWidth.enable[1] = 0x0000000000000000;
	cSettingWidth.enable[2] = 0x0000000000000000;
	cSettingWidth.enable[3] = 0x0000000000000000;
	cSettingWidth.strName = cSettingWidthName;
	cSettingWidth.strValArray = cSettingWidthValArray;

	cSettingHeight.id = 2;
	cSettingHeight.val = 2;
	cSettingHeight.count = 28;
	cSettingHeight.enable[0] = 0x000000000000001F;
	cSettingHeight.enable[1] = 0x0000000000000000;
	cSettingHeight.enable[2] = 0x0000000000000000;
	cSettingHeight.enable[3] = 0x0000000000000000;
	cSettingHeight.strName = cSettingHeightName;
	cSettingHeight.strValArray = cSettingHeightValArray;

	cSettingFPS.id = 3;
	cSettingFPS.val = 1;
	cSettingFPS.count = 62;
	cSettingFPS.enable[0] = 0x000000007FFFFFFF;
	cSettingFPS.enable[1] = 0x0000000000000000;
	cSettingFPS.enable[2] = 0x0000000000000000;
	cSettingFPS.enable[3] = 0x0000000000000000;
	cSettingFPS.strName = cSettingFPSName;
	cSettingFPS.strValArray = cSettingFPSValArray;

	cSettingShutter.id = 4;
	cSettingShutter.val = 2;
	cSettingShutter.count = 19;
	cSettingShutter.enable[0] = 0x000000000007FFFF;
	cSettingShutter.enable[1] = 0x0000000000000000;
	cSettingShutter.enable[2] = 0x0000000000000000;
	cSettingShutter.enable[3] = 0x0000000000000000;
	cSettingShutter.strName = cSettingShutterName;
	cSettingShutter.strValArray = cSettingShutterValArray;

	cState.cSetting[0] = &cSettingMode;
	cState.cSetting[1] = &cSettingWidth;
	cState.cSetting[2] = &cSettingHeight;
	cState.cSetting[3] = &cSettingFPS;
	cState.cSetting[4] = &cSettingShutter;
}

u8 cameraStateSettingEnabled(u8 id, u8 val)
{
	u8 word = val / 64;
	u8 bit = val % 64;
	return ((cState.cSetting[id]->enable[word]) >> (bit)) & 0x1;
}

// Private Function Definitions ----------------------------------------------------------------------------------------
