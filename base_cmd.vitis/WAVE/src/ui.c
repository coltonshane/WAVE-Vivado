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
#include "camera_state.h"
#include "cmv12000.h"
#include "nvme.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define UI_ID_TOP 0
#define UI_ID_BOT 1
#define UI_ID_POP 2

#define FONT_BASE_ADDR 0xC0000000

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
#define CHAR_H 24
#define ROW_H 32

#define PADDING_Y 4

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void uiBuildPopMenu(u8 idSetting);
void uiScrollPopMenu(u8 dir);

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

u32 * uiControl = (u32 *)((u64) 0xA0040050);
const u32 uiBaseAddr[] = {0xA0060000, 0xA0068000, 0xA0070000};

const u16 uiW[] = {1024, 1024, 128};
const u16 uiH[] = {32, 32, 256};

u8 popMenuVal[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
u8 popMenuSelectedVal = 0xFF;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

extern u32 triggerRecordStartStop;
extern u8 popMenuSelectedVal;
void isrUI(void *CallBackRef, u32 Bank, u32 Status)
{
	// triggerRecordStartStop = 1;
	uiScrollPopMenu(1);
}

// Public Function Definitions -----------------------------------------------------------------------------------------

void uiTest(void)
{
	uiHideAll();

	uiClearAll(UI_BG);
	for(u8 i = 0; i < 3; i++)
	{
		uiDrawStringColRow(UI_ID_TOP, cState.cSetting[i]->strValArray[cState.cSetting[i]->val], cState.cSetting[i]->uiOffset, 0);
	}
	uiShow(UI_ID_TOP, 0, 0);

	uiBuildPopMenu(2);
	uiShow(UI_ID_POP, 192 + cState.cSetting[2]->uiOffset * CHAR_W * 2, 0x69);

	uiDrawStringColRow(UI_ID_BOT, "PS: 35*C", 0, 0);
	uiDrawStringColRow(UI_ID_BOT, "PL: 35*C", 16, 0);
	uiDrawStringColRow(UI_ID_BOT, "IS: 35*C", 32, 0);
	uiDrawStringColRow(UI_ID_BOT, "SD: 35*C", 48, 0);
	uiShow(UI_ID_BOT, 0, 0);
}

void uiService(void)
{
	char strResult[9];

	sprintf(strResult, "PS:%3.0f*C", psplGetTemp(psTemp));
	uiDrawStringColRow(UI_ID_BOT, strResult, 0, 0);

	sprintf(strResult, "PL:%3.0f*C", psplGetTemp(plTemp));
	uiDrawStringColRow(UI_ID_BOT, strResult, 16, 0);

	sprintf(strResult, "IS:%3.0f*C", cmvGetTemp());
	uiDrawStringColRow(UI_ID_BOT, strResult, 32, 0);

	sprintf(strResult, "SD:%3.0f*C", nvmeGetTemp());
	uiDrawStringColRow(UI_ID_BOT, strResult, 48, 0);
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void uiBuildPopMenu(u8 idSetting)
{
	popMenuVal[3] = popMenuSelectedVal;

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
		if(cameraStateSettingEnabled(idSetting, val))
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
		if(cameraStateSettingEnabled(idSetting, val))
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
			uiDrawStringColRow(UI_ID_POP, cState.cSetting[idSetting]->strValArray[popMenuVal[i]], 0, i);
		}
		else
		{
			uiDrawStringColRow(UI_ID_POP, "        ", 0, i);
		}
	}

	// Invert the selected settings value.
	uiInvertRectColRow(UI_ID_POP, 0, 3, 8, 1);
}

void uiScrollPopMenu(u8 dir)
{
	if(dir) { popMenuSelectedVal = popMenuVal[4]; }
	else { popMenuSelectedVal = popMenuVal[2]; }
	uiBuildPopMenu(2);
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

	y0 = PADDING_Y + row * ROW_H;

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

	for(u8 y = 0; y < 24; y++)
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

	y0 = row * ROW_H;
	w = wCol * CHAR_W;
	h = hRow * ROW_H;

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
			if((y >= PADDING_Y) && (y < (h - PADDING_Y)))
			{
				*(u32*)((u64) invAddr) = ~(*(u32*)((u64) invAddr));
			}
			else
			{
				*(u32*)((u64) invAddr) = 0xE0E0E0E0;
			}
		}
	}
}
