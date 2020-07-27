/*
UI Methods

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
#include "gpio.h"
#include "camera_state.h"
#include "cmv12000.h"
#include "nvme.h"
#include "fs.h"
#include "frame.h"
#include "supervisor.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define UI_ID_TOP 0
#define UI_ID_BOT 1
#define UI_ID_POP 2

#define FONT_BASE_ADDR 0xC1000000

#define UI_BG 0x20

// UI Control Register Bitfield
#define UI_CONTROL_X0_POS           0
#define UI_CONTROL_Y0_POS          12
#define UI_CONTROL_X0_MASK 0x00000FFF
#define UI_CONTROL_Y0_MASK 0x00FFF000
#define UI_CONTROL_POP_EN  0x01000000
#define UI_CONTROL_BOT_EN  0x02000000
#define UI_CONTROL_TOP_EN  0x04000000

#define FONT_W 1536
#define CHAR_W 16
#define CHAR_H 32

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void uiBuildTopMenu(void);
void uiBuildPopMenu(void);

void uiHideAll(void);
void uiHide(u8 uiID);
void uiShow(u8 uiID, u16 x0, u16 y0);

void uiClearAll(u8 bg);
void uiClear(u8 uiID, u8 bg);

void uiDrawStringColRow(u8 uiID, const char * str, u16 col, u16 row);
void uiDrawString(u8 uiID, const char * str, u16 x0, u16 y0);
void uiDrawChar(u8 uiID, char c, u16 x0, u16 y0);

void uiInvertRectColRow(u8 uiID, u16 col, u16 row, u16 wCol, u16 hRow);
void uiInvertRect(u8 uiID, u16 x0, u16 y0, u16 w, u16 h);

u16 uiColX0(u8 col);
u16 uiRowY0(u8 row);

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

// UI Hardware
u32 * const uiControl = (u32 *)((u64) 0xA0100050);
u32 * const uiPinState = (u32 *)((u64) 0xFF0A0068);
u32 * const gpioPinState = (u32 *)((u64) 0xFF0A006C);
const u32 uiBaseAddr[] = {0xA0168000, 0xA0170000, 0xA0178000};
const u16 uiW[] = {1024, 1024, 128};
const u16 uiH[] = {32, 32, 256};

// UI Event Tracking
u32 uiPinStatePrev = UI_MASK;
u32 gpioPinStatePrev = GPIO_MASK;
XTime tLastRecClick = 0;
u8 uiRecClicked = 0;
u8 uiEncClicked = 0;
int16_t uiEncScrolled = 0;

int topMenuActive = -1;
int topMenuSelectedSetting = -1;

int popMenuActive = -1;
u8 popMenuVal[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
u8 popMenuSelectedVal = 0xFF;

int userInputActive = -1;

u32 uiServiceCounter = 0;

// Interrupt Handlers --------------------------------------------------------------------------------------------------
void isrUI(void *CallBackRef, u32 Bank, u32 Status)
{
	u32 uiPinStateNow = *uiPinState & UI_MASK;
	u32 uiPinStateDiff = uiPinStateNow ^ uiPinStatePrev;
	u32 gpioPinStateNow = *gpioPinState & GPIO_MASK;
	u32 gpioPinStateDiff = gpioPinStateNow ^ gpioPinStatePrev;
	XTime tThisRecClick;
	u8 dir;

	if (Bank == UI_BANK)
	{
		// Register record button click on rising edge.
		if(uiPinStateDiff & UI_REC_SW_MASK)
		{
			if(uiPinStateNow & UI_REC_SW_MASK)
			{
				uiRecClicked = 1;
			}
		}

		// Register encoder button click on rising edge.
		if(uiPinStateDiff & UI_ENC_SW_MASK)
		{
			if(uiPinStateNow & UI_ENC_SW_MASK)
			{
				uiEncClicked = 1;
			}
		}

		// Register encoder scroll on both ENC_A edges, with direction from ENC_B.
		if(uiPinStateDiff & UI_ENC_A_MASK)
		{
			dir = ((uiPinStateNow >> UI_ENC_A_POS) ^ (uiPinStateNow >> UI_ENC_B_POS)) & 0x1;
			if(dir) { uiEncScrolled++; }
			else { uiEncScrolled--; }
		}

		uiPinStatePrev = uiPinStateNow;
	}
	else if (Bank == GPIO_BANK)
	{
		// Register remote start stop input on rising edge.
		if(gpioPinStateDiff & GPIO_REC_SW_MASK)
		{
			if(gpioPinStateNow & GPIO_REC_SW_MASK)
			{
				// Ignore glitches / bouncing less than 500ms.
				XTime_GetTime(&tThisRecClick);
				if((tThisRecClick - tLastRecClick) * US_PER_COUNT > 500000)
				{
					uiRecClicked = 1;
					tLastRecClick = tThisRecClick;
				}
			}
		}

		gpioPinStatePrev = gpioPinStateNow;
	}
}

// Public Function Definitions -----------------------------------------------------------------------------------------

void uiInit(void)
{
	uiHideAll();
	uiClearAll(UI_BG);
}

void uiService(void)
{
	char strWorking[32];

	// Menu state machine.
	// ---------------------------------------------------------------------------------------------

	// Record button has highest priority in REC and STANDBY modes.
	if(cState.cSetting[CSETTING_MODE]->val == CSETTING_MODE_REC)
	{
		if(uiRecClicked)
		{
			// End clip.
			cState.cSetting[CSETTING_MODE]->SetVal(CSETTING_MODE_STANDBY);
			uiBuildTopMenu();
		}
		goto uiServiceComplete;
	}
	else if(cState.cSetting[CSETTING_MODE]->val == CSETTING_MODE_STANDBY)
	{
		if(uiRecClicked)
		{
			// Start clip and close pop-up menu if it's open.
			cState.cSetting[CSETTING_MODE]->SetVal(CSETTING_MODE_REC);
			uiBuildTopMenu();
			popMenuActive = -1;
			uiHide(UI_ID_POP);
			goto uiServiceComplete;
		}
	}

	// Otherwise, handle encoder-based menu interactions.
	if(topMenuActive == -1)
	{
		if(uiEncClicked)
		{
			// Open the top menu.
			topMenuActive = 1;
			topMenuSelectedSetting = -1;
			popMenuActive = -1;
			uiBuildTopMenu();
			uiShow(UI_ID_TOP, 0, 0);
			uiShow(UI_ID_BOT, 0, 0);
		}
	}
	else
	{
		if(popMenuActive == -1)
		{
			if(uiEncClicked)
			{
				if(topMenuSelectedSetting == -1)
				{
					// Clicked the "X", close the top menu.
					topMenuActive = -1;
					uiHide(UI_ID_TOP);
					uiHide(UI_ID_BOT);
				}
				else
				{
					// Clicked a setting, open its pop menu.
					popMenuActive = topMenuSelectedSetting;
					popMenuSelectedVal = cState.cSetting[popMenuActive]->val;
					uiBuildPopMenu();
					uiShow(UI_ID_POP, 192 + (1 + 8 * popMenuActive) * 2 * CHAR_W, 105);
				}
			}
			else if(uiEncScrolled > 0)
			{
				// Scroll right on top menu (if possible).
				topMenuSelectedSetting++;
				if(topMenuSelectedSetting > (CSTATE_NUM_SETTINGS - 1))
				{
					topMenuSelectedSetting = (CSTATE_NUM_SETTINGS - 1);
				}
				else
				{
					uiBuildTopMenu();
				}
			}
			else if(uiEncScrolled < 0)
			{
				// Scroll left on top menu (if possible).
				topMenuSelectedSetting--;
				if(topMenuSelectedSetting < -1)
				{
					topMenuSelectedSetting = -1;
				}
				else
				{
					uiBuildTopMenu();
				}
			}
		}
		else
		{
			if(userInputActive == -1)
			{
				if(uiEncClicked)
				{
					if(cSettingGetUser(topMenuSelectedSetting, popMenuSelectedVal))
					{
						// Enter user input state.
						userInputActive = 1;
						uiBuildPopMenu();
					}
					else
					{
						// Apply new setting and close the pop menu.
						cState.cSetting[popMenuActive]->SetVal(popMenuSelectedVal);
						cStateApply();
						uiBuildTopMenu(); 		// To reflect the new setting.
						popMenuActive = -1;
						uiHide(UI_ID_POP);
					}
				}
				else if(uiEncScrolled > 0)
				{
					// Scroll down in pop menu (if possible).
					if(popMenuVal[4] < 0xFF)
					{
						popMenuSelectedVal = popMenuVal[4];
						cState.cSetting[popMenuActive]->PreviewVal(popMenuSelectedVal);
						uiBuildPopMenu();
					}
				}
				else if(uiEncScrolled < 0)
				{
					// Scroll up in pop menu (if possible).
					if(popMenuVal[2] < 0xFF)
					{
						popMenuSelectedVal = popMenuVal[2];
						cState.cSetting[popMenuActive]->PreviewVal(popMenuSelectedVal);
						uiBuildPopMenu();
					}
				}
			}
			else
			{
				if(uiEncClicked)
				{
					// Exit user input stage, apply new setting, and close the pop menu.
					cState.cSetting[popMenuActive]->SetVal(popMenuSelectedVal);
					cStateApply();
					uiBuildTopMenu(); 		// To reflect the new setting.
					userInputActive = -1;
					popMenuActive = -1;
					uiHide(UI_ID_POP);
				}
				else if(uiEncScrolled > 0)
				{
					// Increment the user value.
					cState.cSetting[topMenuSelectedSetting]->valArray[popMenuSelectedVal].fVal += 1.0f;
					cState.cSetting[popMenuActive]->PreviewVal(popMenuSelectedVal);
					uiBuildPopMenu();
				}
				else if(uiEncScrolled < 0)
				{
					// Decrement the user value.
					cState.cSetting[topMenuSelectedSetting]->valArray[popMenuSelectedVal].fVal -= 1.0f;
					cState.cSetting[popMenuActive]->PreviewVal(popMenuSelectedVal);
					uiBuildPopMenu();
				}
			}
		}
	}
	// ---------------------------------------------------------------------------------------------

uiServiceComplete:

	uiServiceCounter++;

	// Discard UI events, even if they are unused.
	uiRecClicked = 0;
	uiEncClicked = 0;
	uiEncScrolled = 0;

	sprintf(strWorking, "c%04d", nClip);
	uiDrawStringColRow(UI_ID_BOT, strWorking, 0, 0);

	sprintf(strWorking, "%5.2f:1 Q%-2d", frameCompressionRatio, frameCompressionProfile);
	uiDrawStringColRow(UI_ID_BOT, strWorking, 8, 0);

	sprintf(strWorking, "%4d/%-4d GB", fsFreeGB, fsSizeGB);
	uiDrawStringColRow(UI_ID_BOT, strWorking, 20, 0);

	sprintf(strWorking, "%3.0f*C", psplGetTemp(psTemp));
	uiDrawStringColRow(UI_ID_BOT, strWorking, 48, 0);

	sprintf(strWorking, "%2d.%1dV", supervisorVBatt / 10, supervisorVBatt % 10);
	if((supervisorVBatt < 100) && ((uiServiceCounter % 32) < 16))
	{ uiDrawStringColRow(UI_ID_BOT, " LOW ", 54, 0); }
	else
	{ uiDrawStringColRow(UI_ID_BOT, strWorking, 54, 0); }

	/*
	// Temperature Details
	sprintf(strWorking, "PS:%3.0f*C", psplGetTemp(psTemp));
	uiDrawStringColRow(UI_ID_BOT, strWorking, 0, 0);

	sprintf(strWorking, "PL:%3.0f*C", psplGetTemp(plTemp));
	uiDrawStringColRow(UI_ID_BOT, strWorking, 16, 0);

	sprintf(strWorking, "IS:%3.0f*C", cmvGetTemp());
	uiDrawStringColRow(UI_ID_BOT, strWorking, 32, 0);

	sprintf(strWorking, "SD:%3.0f*C", nvmeGetTemp());
	uiDrawStringColRow(UI_ID_BOT, strWorking, 48, 0);
	*/
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void uiBuildTopMenu(void)
{
	u8 col;
	char strVal[8];

	uiDrawStringColRow(UI_ID_TOP, "X", 0, 0);
	for(u8 i = 0; i < CSTATE_NUM_SETTINGS; i++)
	{
		col = 1 + 8 * i;
		switch(cState.cSetting[i]->uiDisplayType)
		{
		case CSETTING_UI_DISPLAY_TYPE_VAL_ARRAY:
			uiDrawStringColRow(UI_ID_TOP, cState.cSetting[i]->valArray[cState.cSetting[i]->val].strName, col, 0);
			break;
		case CSETTING_UI_DISPLAY_TYPE_VAL_FORMAT_INT:
			sprintf(strVal, cState.cSetting[i]->strValFormat, (int)(cState.cSetting[i]->valArray[cState.cSetting[i]->val].fVal));
			uiDrawStringColRow(UI_ID_TOP, strVal, col, 0);
			break;
		case CSETTING_UI_DISPLAY_TYPE_NAME:
		default:
			uiDrawStringColRow(UI_ID_TOP, cState.cSetting[i]->strName, col, 0);
		}
	}
	if(topMenuSelectedSetting > -1)
	{
		col = 1 + 8 * topMenuSelectedSetting;
		uiInvertRectColRow(UI_ID_TOP, col, 0, 8, 1);
	}
	else
	{
		uiInvertRectColRow(UI_ID_TOP, 0, 0, 1, 1);
	}
}

void uiBuildPopMenu()
{
	popMenuVal[3] = popMenuSelectedVal;
	u8 idSetting = topMenuSelectedSetting;
	char strVal[8];

	// Populate valid settings in the forward direction.
	u8 val = popMenuSelectedVal;
	for (int i = 4; i <= 7; )
	{
		if(val < (cState.cSetting[idSetting]->count - 1))
		{
			val++;
		}
		else
		{
			popMenuVal[i] = 0xFF;
			i++;
			continue;
		}
		if(cSettingGetEnabled(idSetting, val))
		{
			popMenuVal[i] = val;
			i++;
		}
	}

	// Populate valid settings in the reverse direction.
	val = popMenuSelectedVal;
	for (int i = 2; i >= 0; )
	{
		if(val > 0)
		{
			val--;
		}
		else
		{
			popMenuVal[i] = 0xFF;
			i--;
			continue;
		}
		if(cSettingGetEnabled(idSetting, val))
		{
			popMenuVal[i] = val;
			i--;
		}
	}

	// Draw strings for settings values.
	for(u8 i = 0; i <= 7; i++)
	{
		if(popMenuVal[i] < 0xFF)
		{
			if((i == 3) && (userInputActive == 1))
			{
				// If the user input is active, show the formatted value instead of its string array entry.
				sprintf(strVal, cState.cSetting[i]->strValFormat, (int)(cState.cSetting[i]->valArray[popMenuVal[i]].fVal));
				uiDrawStringColRow(UI_ID_POP, strVal, 0, i);
			}
			else
			{
				uiDrawStringColRow(UI_ID_POP, cState.cSetting[idSetting]->valArray[popMenuVal[i]].strName, 0, i);
			}
		}
		else
		{
			uiDrawStringColRow(UI_ID_POP, "        ", 0, i);
		}
	}

	// Invert the selected settings value.
	uiInvertRectColRow(UI_ID_POP, 0, 3, 8, 1);
}

void uiHideAll(void)
{
	uiHide(UI_ID_POP);
	uiHide(UI_ID_BOT);
	uiHide(UI_ID_TOP);
}

void uiHide(u8 uiID)
{
	if(uiID == UI_ID_POP)
	{
		*uiControl &= ~UI_CONTROL_POP_EN;
	}
	else if (uiID == UI_ID_BOT)
	{
		*uiControl &= ~UI_CONTROL_BOT_EN;
	}
	else if (uiID == UI_ID_TOP)
	{
		*uiControl &= ~UI_CONTROL_TOP_EN;
	}
}

void uiShow(u8 uiID, u16 x0, u16 y0)
{
	if(uiID > UI_ID_POP) { return; }

	if(uiID == UI_ID_POP)
	{
		if((x0 < 192) || (x0 >= 1984)) { return; }
		if((y0 < 41) || (y0 >= 865)) { return; }

		*uiControl &= ~(UI_CONTROL_Y0_MASK | UI_CONTROL_X0_MASK);
		*uiControl |= (x0 << UI_CONTROL_X0_POS) & UI_CONTROL_X0_MASK;
		*uiControl |= (y0 << UI_CONTROL_Y0_POS) & UI_CONTROL_Y0_MASK;
		*uiControl |= UI_CONTROL_POP_EN;
	}
	else if(uiID == UI_ID_BOT)
	{
		*uiControl |= UI_CONTROL_BOT_EN;
	}
	else if(uiID == UI_ID_TOP)
	{
		*uiControl |= UI_CONTROL_TOP_EN;
	}
}

void uiClearAll(u8 bg)
{
	uiClear(UI_ID_POP, bg);
	uiClear(UI_ID_BOT, bg);
	uiClear(UI_ID_TOP, bg);
}

void uiClear(u8 uiID, u8 bg)
{
	if(uiID > UI_ID_POP) { return; }

	memset((void *) ((u64) uiBaseAddr[uiID]), bg, 32768);
}

void uiDrawStringColRow(u8 uiID, const char * str, u16 col, u16 row)
{
	u16 x0, y0;
	// All argument validation deferred to uiDrawString().

	if(uiID == UI_ID_POP)
	{
		x0 = col * CHAR_W;
	}
	else
	{
		// Add 32 pixels for invisible X margins on top and bottom UI.
		x0 = 32 + col * CHAR_W;
	}

	y0 = row * CHAR_H;

	uiDrawString(uiID, str, x0, y0);
}

void uiDrawString(u8 uiID, const char * str, u16 x0, u16 y0)
{
	uint32_t len;

	if(uiID > UI_ID_POP) { return; }

	len = strlen(str);
	if(len > 60) { return; }

	// Force X alignment to 32b.
	x0 &= 0xFFFC;

	if(x0 > (uiW[uiID] - CHAR_W)) { return; }	// Partial strings will be drawn.
	if(y0 > (uiH[uiID] - CHAR_H)) { return; }

	// Further argument validation occurs in uiDrawChar().

	for (uint8_t c = 0; c < len; c++)
	{
		uiDrawChar(uiID, str[c], x0 + 16 * c, y0);
	}
}

void uiDrawChar(u8 uiID, char c, u16 x0, u16 y0)
{
	u32 srcAddr;
	u32 destAddr;

	if(uiID > UI_ID_POP) { return; }

	// Force X alignment to 32b.
	x0 &= 0xFFFC;

	if(x0 > (uiW[uiID] - CHAR_W)) { return; }
	if(y0 > (uiH[uiID] - CHAR_H)) { return; }
	if ((c < 32) || (c >= 128)) { c = '?'; }

	for(u8 y = 0; y < CHAR_H; y++)
	{
		srcAddr = FONT_BASE_ADDR + FONT_W * y + CHAR_W * (c - 32);
		destAddr = uiBaseAddr[uiID] + uiW[uiID] * (y0 + y) + x0;
		memcpy((void *) ((u64) destAddr), (void *) ((u64) srcAddr), CHAR_W);
	}
}

void uiInvertRectColRow(u8 uiID, u16 col, u16 row, u16 wCol, u16 hRow)
{
	u16 x0, y0, w, h;
	// All argument validation deferred to uiDrawString().

	if(uiID == UI_ID_POP)
	{
		x0 = col * CHAR_W;
	}
	else
	{
		// Add 32 pixels for invisible X margins on top and bottom UI.
		x0 = 32 + col * CHAR_W;
	}

	y0 = row * CHAR_H;
	w = wCol * CHAR_W;
	h = hRow * CHAR_H;

	uiInvertRect(uiID, x0, y0, w, h);
}

void uiInvertRect(u8 uiID, u16 x0, u16 y0, u16 w, u16 h)
{
	u32 invAddr;

	if(uiID > UI_ID_POP) { return; }

	// Force X alignment to 32b.
	x0 &= 0xFFFC;
	w &= 0xFFFC;

	if(x0 > (uiW[uiID] - w)) { return; }
	if(y0 > (uiH[uiID] - h)) { return; }

	for(u8 y = 0; y < h; y += 1)
	{
		for(u8 x = 0; x < w; x += 4)
		{
			invAddr = uiBaseAddr[uiID] + uiW[uiID] * (y0 + y) + x0 + x;
			*(u32*)((u64) invAddr) = ~(*(u32*)((u64) invAddr));
		}
	}
}
