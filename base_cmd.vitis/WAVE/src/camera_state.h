/*
WAVE State Machine Includes

cState defines the entire configurable state of the camera. This includes
all settings that can be changed on the fly from the UI, external commands,
loading of saved configurations, etc. It drives all subsystem and peripheral
configuration steps through PushCameraState(), a one-way process that assumes
success, i.e. a valid CameraState to push.

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

#ifndef __CAMERA_STATE_INCLUDE__
#define __CAMERA_STATE_INCLUDE__

// Include Headers -----------------------------------------------------------------------------------------------------

// Public Pre-Processor Definitions ------------------------------------------------------------------------------------

#define CSTATE_NUM_SETTINGS 6

#define CSETTING_UI_DISPLAY_TYPE_NAME 0
#define CSETTING_UI_DISPLAY_TYPE_VAL 1

// Public Type Definitions ---------------------------------------------------------------------------------------------

typedef struct
{
	u8 id;
	u8 val;
	u8 count;
	u64 enable[4];

	char * strName;
	char ** strValArray;
	u8 uiDisplayType;
} CameraSetting_s;

typedef struct
{
	CameraSetting_s * cSetting[CSTATE_NUM_SETTINGS];
} CameraState_s;

// Public Function Prototypes ------------------------------------------------------------------------------------------

void cameraStateInit(void);
u8 cameraStateSettingEnabled(u8 id, u8 val);

// Externed Public Global Variables ------------------------------------------------------------------------------------
extern CameraState_s cState;

#endif
