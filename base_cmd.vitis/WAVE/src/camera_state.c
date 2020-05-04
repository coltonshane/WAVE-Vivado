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
	cSettingHeight.enable[0] = 0x000000000FFFFFFF;
	cSettingHeight.enable[1] = 0x0000000000000000;
	cSettingHeight.enable[2] = 0x0000000000000000;
	cSettingHeight.enable[3] = 0x0000000000000000;

	cSettingHeight.strName = cSettingHeightName;
	cSettingHeight.strValArray = cSettingHeightValArray;

	cState.cSetting[0] = &cSettingMode;
	cState.cSetting[1] = &cSettingWidth;
	cState.cSetting[2] = &cSettingHeight;
}

u8 cameraStateSettingEnabled(u8 id, u8 val)
{
	u8 word = val / 64;
	u8 bit = val % 64;
	return ((cState.cSetting[id]->enable[word]) >> (bit)) & 0x1;
}

// Private Function Definitions ----------------------------------------------------------------------------------------
