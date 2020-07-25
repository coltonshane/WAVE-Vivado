/*
CMV12000 Driver

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

#include "cmv12000.h"
#include "supervisor.h"
#include "gpio.h"
#include "camera_state.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define SPI0_DEVICE_ID XPAR_XSPIPS_0_DEVICE_ID

// Channel control and data masks.
#define PX_DATA_MASK  0x0000FFFF
#define PX_DELAY_MASK 0x00FF0000
#define PX_DELAY_POS 16
#define PX_BITSLIP_MASK 0x0F000000
#define PX_BITSLIP_POS 24
#define PX_PHASE_MASK 0x30000000
#define PX_PHASE_POS 28

#define CMV_RD_REG 0x00
#define CMV_WR_REG 0x80
#define CMV_ADDR_MASK 0x7F

#define CMV_REG_COUNT_INIT 14
#define CMV_REG_COUNT_SETTINGS 27

// Bit patterns for link training.
#define CMV_TP1 0x0055
#define CMV_TPC 0x0080

// Dark frame mapping modes.
#define CMV_DARK_FRAME_4K 0
#define CMV_DARK_FRAME_2K 1

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

void cmvLinkTrain(void);
void cmvRegInit(XSpiPs * spiDevice);
void cmvTestDarkFrame(void);
void cmvMapDarkFrame(float * darkCol, float * darkRow, u8 mode);

u16 cmvRegRead(XSpiPs * spiDevice, u8 addr);
void cmvRegWrite(XSpiPs * spiDevice, u8 addr, u16 val);

// Public Global Variables ---------------------------------------------------------------------------------------------

CMV_Input_s * CMV_Input =  (CMV_Input_s *) 0xA0200000;
u32 * const lutDarkCol[] = { (u32 * const) 0xA0208000,
							 (u32 * const) 0xA0210000,
							 (u32 * const) 0xA0218000,
							 (u32 * const) 0xA0220000,
							 (u32 * const) 0xA0228000,
							 (u32 * const) 0xA0230000,
							 (u32 * const) 0xA0238000,
							 (u32 * const) 0xA0240000  };
u32 * const lutDarkRow =     (u32 * const) 0xA0248000;

// Private Global Variables --------------------------------------------------------------------------------------------

XSpiPs Spi0;
XSpiPs_Config *spi0Config;

// Registers that are initialized to constant but non-default values.
u8 cmvRegAddrInit[] =
{
	69,
	70,
	80,
	89,
	99,
	102,
	107,
	108,
	109,
	110,
	112,
	116,
	123,
	124
};
u16 cmvRegValInit[] =
{
	1,
	0,
	1,
	32853,
	34956,
	8302,
	11614,
	12381,
	13416,
	12368,
	277,
	421,
	50,
	15
};

// Registers that are accessible via the UI.
CMV_Settings_s CMV_Settings_W, CMV_Settings_R;
u8 cmvRegAddrSettings[] = {1,2,66,67,68,71,72,75,76,77,78,79,82,83,84,85,86,87,88,98,106,113,114,115,117,122,127};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void cmvInit(void)
{
	// Set the frame interval timer to a safe value and don't request frames yet.
	CMV_Input->frame_interval = 2500000;	// 24fps
	CMV_Input->FRAME_REQ_on = 0xFFFFFFFF;	// Never.
	CMV_Input->T_EXP1_on = 0xFFFFFFFF;		// Never.
	CMV_Input->T_EXP2_on = 0xFFFFFFFF;		// Never.

    // Set up SPI0 for CMV12000 serial control.
	spi0Config = XSpiPs_LookupConfig(SPI0_DEVICE_ID);
    XSpiPs_CfgInitialize(&Spi0, spi0Config, spi0Config->BaseAddress);
    XSpiPs_SetOptions(&Spi0, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION);
    XSpiPs_SetClkPrescaler(&Spi0, XSPIPS_CLK_PRESCALE_64);
    XSpiPs_SetSlaveSelect(&Spi0, 0x0F);

	// Hold the pixel input blocks in reset until the LVDS clock is available.
	XGpioPs_WritePin(&Gpio, PX_IN_RST_PIN, 1);

	// Tell the supervisor to enable the CMV12000 power supplies. Wait for power good signals.
	supervisorEnableCMVPower();
	usleep(1000);

	// Start the 600MHz LVDS clock.
	XGpioPs_WritePin(&Gpio, LVDS_CLK_EN_PIN, 1);
	usleep(10);

	// Take the CMV12000 out of reset.
	XGpioPs_WritePin(&Gpio, CMV_NRST_PIN, 1);
	usleep(10);

	// Take the pixel input blocks out of reset.
	XGpioPs_WritePin(&Gpio, PX_IN_RST_PIN, 0);
	usleep(1000);

	// Run link training on the CMV12000.
	cmvLinkTrain();

	usleep(1000);

	cmvRegInit(&Spi0);
	cmvApplyCameraState();
	cmvService();

	cmvTestDarkFrame();
}

void cmvService(void)
{
	// Read CMV12000 settings in CMV_Settings_s packed order.
	for(u8 i = 0; i < CMV_REG_COUNT_SETTINGS; i++)
	{
		*((u16 *)(&CMV_Settings_R) + i) = cmvRegRead(&Spi0, cmvRegAddrSettings[i]);
	}

	// Write modified CMV12000 settings (that don't match reads), except for Temp_sensor.
	for(u8 i = 0; i < (CMV_REG_COUNT_SETTINGS - 1); i++)
	{
		if(*((u16 *)(&CMV_Settings_R) + i) != *((u16 *)(&CMV_Settings_W) + i))
		{
			cmvRegWrite(&Spi0, cmvRegAddrSettings[i], *((u16 *)(&CMV_Settings_W) + i));
		}
	}
}

void cmvApplyCameraState(void)
{
	u16 h;
	u8 r82lsb, r82msb, r85;
	float fPixel = 60E6f;
	float tLine, tFOT, tFrame;
	float tExp, tExpMax;
	float fExpLines;
	int iExpLines;
	int iExp_kp1;
	int iExp_kp2;

	h = (u16)(cState.cSetting[CSETTING_HEIGHT]->valArray[cState.cSetting[CSETTING_HEIGHT]->val].fVal);

	if(cState.cSetting[CSETTING_WIDTH]->valArray[cState.cSetting[CSETTING_WIDTH]->val].fVal == 4096.0f)
	{
		// 4K Mode.
		CMV_Settings_W.Number_lines_tot = h;
		CMV_Settings_W.Y_start_1 = (3072 - h) / 2;			// Always in [0 to 3071] range.
		CMV_Settings_W.Sub_step = 1;
		CMV_Settings_W.Sub_en = 0;
		CMV_Settings_W.Setting_1 = 3099;
		CMV_Settings_W.Setting_2 = 5893;
		CMV_Settings_W.Setting_3 = 128;
		CMV_Settings_W.Setting_4 = 128;
		CMV_Settings_W.Setting_5 = 128;
		CMV_Settings_W.Offset_bot = 480;
		CMV_Settings_W.Offset_top = 480;
		CMV_Settings_W.Reg_98 = 44812;
		CMV_Settings_W.Setting_6 = 789;
		CMV_Settings_W.Setting_7 = 84;
	}
	else
	{
		// 2K Mode.
		CMV_Settings_W.Number_lines_tot = h;
		CMV_Settings_W.Y_start_1 = (3072 - 2 * h) / 2;		// Always in [0 to 3071] range.
		CMV_Settings_W.Sub_step = 2;
		CMV_Settings_W.Sub_en = 2;
		CMV_Settings_W.Setting_1 = 2843;
		CMV_Settings_W.Setting_2 = 5891;
		CMV_Settings_W.Setting_3 = 143;
		CMV_Settings_W.Setting_4 = 143;
		CMV_Settings_W.Setting_5 = 71;
		CMV_Settings_W.Offset_bot = 520;
		CMV_Settings_W.Offset_top = 520;
		CMV_Settings_W.Reg_98 = 44815;
		CMV_Settings_W.Setting_6 = 798;
		CMV_Settings_W.Setting_7 = 90;
	}

	CMV_Settings_W.Sub_offset = 0;

	r82lsb = CMV_Settings_W.Setting_1 & 0xFF;
	r82msb = (CMV_Settings_W.Setting_1 >> 8) & 0xFF;
	r85 = CMV_Settings_W.Setting_4;

	// Set Exp_time setting based on CMV12000 datasheet.
	tLine = (float)(r85 + 1) / fPixel;
	tFOT = (float)(r82msb + 2) * tLine;
	tFrame = 1.0f / cState.cSetting[CSETTING_FPS]->valArray[cState.cSetting[CSETTING_FPS]->val].fVal;
	tExp = tFrame * cState.cSetting[CSETTING_SHUTTER]->valArray[cState.cSetting[CSETTING_SHUTTER]->val].fVal / 360.0f;
	tExpMax = tFrame - tFOT + (float)(34 * (int)r82lsb) / fPixel;
	if(tExp > tExpMax) { tExp = tExpMax; }
	fExpLines = (tExp - (float)(1 + 34 * (int)r82lsb) / fPixel) / tLine + 1.0f;
	iExpLines = (int)fExpLines;
	if(iExpLines < 0) { iExpLines = 0; }
	else if(iExpLines > 0xFFFFFF) { iExpLines = 0xFFFFFF; }

	// Set the multi-slope exposure times to 10% and 1%.
	iExp_kp1 = iExpLines / 10;
	iExp_kp2 = iExpLines / 100;

	CMV_Settings_W.Exp_time_L = (iExpLines & 0xFFFF);
	CMV_Settings_W.Exp_time_H = (iExpLines >> 16) & 0xFF;
	CMV_Settings_W.Exp_kp1_L = (iExp_kp1 & 0xFFFF);
	CMV_Settings_W.Exp_kp1_H = (iExp_kp1 >> 16) & 0xFF;
	CMV_Settings_W.Exp_kp2_L = (iExp_kp2 & 0xFFFF);
	CMV_Settings_W.Exp_kp2_H = (iExp_kp2 >> 16) & 0xFF;
	CMV_Settings_W.Number_slopes = 1;

	// Set the frame interval.
	CMV_Input->frame_interval = tFrame * 60E6;

	CMV_Settings_W.Vtfl = 84 * 128 + 104;

	CMV_Settings_W.PGA_gain = CMV_REG_VAL_PGA_GAIN_X1;
	CMV_Settings_W.DIG_gain = 4;
	CMV_Settings_W.Test_pattern = 32;
	CMV_Settings_W.Temp_sensor = 0;
}

float cmvGetTemp(void)
{
	// TO-DO: Move to calibration.
	static float cmvDN0 = 1556.0f;
	static float cmvT0 = 30.0f;
	static float cmvTSlope = 0.143f;

	static float cmvTf = -100.0f;

	float cmvT = ((float)(CMV_Settings_R.Temp_sensor) - cmvDN0) * cmvTSlope + cmvT0;
	if(cmvTf == -100.0f)
	{
		cmvTf = cmvT;
	}
	else
	{
		cmvTf = 0.95f * cmvTf + 0.05f * cmvT;
	}

	return cmvTf;
}

u32 cmvGetExposure(void)
{
	// TO-DO: Add a bit flag for three-slope exposure enabled.
	return ((u32)CMV_Settings_R.Exp_time_H << 16) | (u32)CMV_Settings_R.Exp_time_L;
}

// Private Function Definitions ----------------------------------------------------------------------------------------

// CMV12000 Link Training Routine
void cmvLinkTrain(void)
{
    // Stage 1: Find the correct phase for the deserializer clocks.
    // -----------------------------------------------------------------------------------------
    uint8_t px_phase = 0;
    uint16_t px_data = 0;
    uint16_t px_data_prev = 0;
    uint32_t px_data_diff = 0;

    do
    {
    	px_data_diff = 0;
    	px_data_prev = CMV_Input->ch[64] & PX_DATA_MASK;
    	usleep(1);

    	// Do 1024 consecutive reads of the control channel.
    	for(u32 i = 0; i < 1024; i++)
    	{
    		px_data = CMV_Input->ch[64] & PX_DATA_MASK;
    		if(px_data != px_data_prev)
    		{ px_data_diff++; }
    		px_data_prev = px_data;
    		usleep(1);
    	}

    	// If the read data is not stable, try a different phase.
    	if(px_data_diff != 0)
    	{
    		px_phase = (px_phase + 1) % 4;
    		CMV_Input->ch[64] &= ~PX_PHASE_MASK;
    		CMV_Input->ch[64] |= (px_phase << PX_PHASE_POS);
    		usleep(10);
    	}
    }
    while (px_data_diff != 0);

    // Set all pixel channels to the same phase as the control channel.
    for(u32 ch = 0; ch < 64; ch++)
    {
    	CMV_Input->ch[ch] &= ~PX_PHASE_MASK;
    	CMV_Input->ch[ch] |= (px_phase << PX_PHASE_POS);
    }
    // -----------------------------------------------------------------------------------------

    usleep(1000);

    // Stage 2: Find eye centers for each channel.
    // -----------------------------------------------------------------------------------------
    uint16_t px_data_prev2[65];
    uint32_t px_delay_start[65];
    uint32_t px_delay_width[65];
    uint32_t px_eye_start[65];
    uint32_t px_eye_width[65];
    uint32_t px_eye_center[65];
    for(u32 ch = 0; ch < 65; ch++)
    {
    	px_data_prev2[ch] = 0xFFFF;
    	px_delay_start[ch] = 0;
    	px_delay_width[ch] = 0;
    	px_eye_start[ch] = 0;
    	px_eye_width[ch] = 0;
    	px_eye_center[ch] = 0;
    }

    // Scan through the entire range of delay values.
    for(u32 d = 0; d < 256; d++)
    {
    	// Set the new delay on all channels and wait 1ms for it to take effect.
    	for(u32 ch = 0; ch < 65; ch++)
    	{
    		CMV_Input->ch[ch] &= ~PX_DELAY_MASK;
    		CMV_Input->ch[ch] |= (d << PX_DELAY_POS);
    	}

    	usleep(1000);

    	// Seek the maximum width eye (where the data doesn't change).
    	for(u32 ch = 0; ch < 65; ch++)
    	{
    		px_data = CMV_Input->ch[ch] & PX_DATA_MASK;
    		if(px_data == px_data_prev2[ch])
    		{
    			px_delay_width[ch]++;
    		}
    		else
    		{
    			// Require a width increase of 12.5% or more, to prefer the first eye.
    			if(px_delay_width[ch] > ((px_eye_width[ch] * 18) >> 4))
    			{
    				px_eye_start[ch] = px_delay_start[ch];
    				px_eye_width[ch] = px_delay_width[ch];
    			}

    			px_delay_width[ch] = 0;
    			px_delay_start[ch] = d;
    		}

    		px_data_prev2[ch] = px_data;
    	}
    }

    // Set the delay to the center of the largest eye.
    for(u32 ch = 0; ch < 65; ch++)
    {
    	px_eye_center[ch] = px_eye_start[ch] + (px_eye_width[ch] >> 1);
    	CMV_Input->ch[ch] &= ~PX_DELAY_MASK;
    	CMV_Input->ch[ch] |= (px_eye_center[ch] << PX_DELAY_POS);
    }

    // -----------------------------------------------------------------------------------------

    usleep(1000);

    // Stage 3: Set the bit slip to align to the CMV12000 idle training pattern.
    // -----------------------------------------------------------------------------------------
    uint8_t ctr_bitslip;
    uint8_t chXX_bitslip[64];

    // Find the control channel bitslip in the range of 3-12.
    ctr_bitslip = 3;

    do
    {
    	CMV_Input->ch[64] &= ~PX_BITSLIP_MASK;
    	CMV_Input->ch[64] |= (ctr_bitslip << PX_BITSLIP_POS);
    	usleep(10);
    	px_data = CMV_Input->ch[64] & PX_DATA_MASK;

    	if(px_data != CMV_TPC)
    	{
    		ctr_bitslip++;
    	}
    }
    while((px_data != CMV_TPC) && (ctr_bitslip < 13));

    // Find the pixel channel bitslips in the range of (ctr_bitslip +/- 3).
    for(u32 ch = 0; ch < 64; ch++)
    {
    	chXX_bitslip[ch] = ctr_bitslip - 3;
    	do
    	{
    		CMV_Input->ch[ch] &= ~PX_BITSLIP_MASK;
    		CMV_Input->ch[ch] |= (chXX_bitslip[ch] << PX_BITSLIP_POS);
    		usleep(10);
    		px_data = CMV_Input->ch[ch] & PX_DATA_MASK;

    	    if(px_data != CMV_TP1)
    	    {
    	    	chXX_bitslip[ch]++;
    	    }
    	}
    	while((px_data != CMV_TP1) && (chXX_bitslip[ch] < (ctr_bitslip + 4)));
    }
    // -----------------------------------------------------------------------------------------

    // Disable px_count_limit by setting it to max.
    CMV_Input->px_count_limit = 0x7FFFFF;

    // Make sure the FOT interrupt flag is cleared.
    CMV_Input->FOT_int = 0;
}

void cmvRegInit(XSpiPs * spiDevice)
{
	for(u8 i = 0; i < CMV_REG_COUNT_INIT; i++)
	{
		cmvRegWrite(spiDevice, cmvRegAddrInit[i], cmvRegValInit[i]);
		usleep(10);
	}
}

float darkColTest[4096];
float darkRowTest[3072];
void cmvTestDarkFrame(void)
{
	/*
	for(int x = 0; x < 4096; x++)
	{
		if(x < 64)
		{
			darkColTest[x] = 0.02f;
		}
		else
		{
			darkColTest[x] = 0.0f;
		}
	}

	for(int y = 0; y < 3072; y++)
	{
		if(y < 1088)
		{
			darkRowTest[y] = 0.02f;
		}
		else
		{
			darkRowTest[y] = 0.0f;
		}
	}
	*/

	for(int x = 0; x < 2048; x++)
	{
		if(x < 1024)
		{
			darkColTest[x] = 0.02f;
		}
		else
		{
			darkColTest[x] = 0.0f;
		}
	}

	for(int y = 0; y < 1536; y++)
	{
		if(y < 272)
		{
			darkRowTest[y] = 0.02f;
		}
		else
		{
			darkRowTest[y] = 0.0f;
		}
	}

	cmvMapDarkFrame(darkColTest, darkRowTest, CMV_DARK_FRAME_2K);
}

void cmvMapDarkFrame(float * darkCol, float * darkRow, u8 mode)
{
	u64 lutEntry;
	u8 cidx;

	if(mode == CMV_DARK_FRAME_4K)
	{
		// 4K Mapping
		// Columns
		for(int c = 0; c < 128; c++)
		{
			// By Column Group
			for(int cg = 0; cg < 8; cg++)
			{
				// X flip handled here.
				lutEntry =  (u64)((u16)(darkCol[(4 * (7 - cg) + 0) * 128 + c] * 1024.0f)) << 48;
				lutEntry += (u64)((u16)(darkCol[(4 * (7 - cg) + 1) * 128 + c] * 1024.0f)) << 32;
				lutEntry += (u64)((u16)(darkCol[(4 * (7 - cg) + 2) * 128 + c] * 1024.0f)) << 16;
				lutEntry += (u64)((u16)(darkCol[(4 * (7 - cg) + 3) * 128 + c] * 1024.0f)) << 0;
				lutDarkCol[cg][2 * c + 0] = lutEntry & 0xFFFFFFFF;
				lutDarkCol[cg][2 * c + 1] = lutEntry >> 32;
			}
		}
		// Rows
		for(int r = 0; r < 1536; r++)
		{
			lutEntry =  (u64)((u16)(darkRow[2 * r + 0] * 1024.0f)) << 0;
			lutEntry += (u64)((u16)(darkRow[2 * r + 1] * 1024.0f)) << 16;
			lutEntry += (u64)((u16)(darkRow[2 * r + 0] * 1024.0f)) << 32;	// Repeat Row N+0
			lutEntry += (u64)((u16)(darkRow[2 * r + 1] * 1024.0f)) << 48;	// Repeat Row N+1
			lutDarkRow[2 * r + 0] = lutEntry & 0xFFFFFFFF;
			lutDarkRow[2 * r + 1] = lutEntry >> 32;
		}
	}
	else
	{
		// 2K Mapping
		// Columns
		for(int c = 0; c < 64; c++)
		{
			// By Column Group
			for(int cg = 0; cg < 8; cg++)
			{
				// X flip handled here.
				lutEntry =  (u64)((u16)(darkCol[(4 * (7 - cg) + 0) * 64 + c] * 1024.0f)) << 48;
				lutEntry += (u64)((u16)(darkCol[(4 * (7 - cg) + 1) * 64 + c] * 1024.0f)) << 32;
				lutEntry += (u64)((u16)(darkCol[(4 * (7 - cg) + 2) * 64 + c] * 1024.0f)) << 16;
				lutEntry += (u64)((u16)(darkCol[(4 * (7 - cg) + 3) * 64 + c] * 1024.0f)) << 0;
				cidx = 4 * (c >> 1) + (c & 0x1);
				lutDarkCol[cg][2 * (cidx) + 0] = lutEntry & 0xFFFFFFFF;
				lutDarkCol[cg][2 * (cidx) + 1] = lutEntry >> 32;
				cidx += 2;
				lutDarkCol[cg][2 * (cidx) + 0] = lutEntry & 0xFFFFFFFF;		// Repeat Col N+0
				lutDarkCol[cg][2 * (cidx) + 1] = lutEntry >> 32;			// Repeat Col N+1
			}
		}
		// Rows
		for(int r = 0; r < 384; r++)
		{
			lutEntry =  (u64)((u16)(darkRow[4 * r + 0] * 1024.0f)) << 0;
			lutEntry += (u64)((u16)(darkRow[4 * r + 1] * 1024.0f)) << 16;
			lutEntry += (u64)((u16)(darkRow[4 * r + 2] * 1024.0f)) << 32;
			lutEntry += (u64)((u16)(darkRow[4 * r + 3] * 1024.0f)) << 48;
			lutDarkRow[2 * r + 0] = lutEntry & 0xFFFFFFFF;
			lutDarkRow[2 * r + 1] = lutEntry >> 32;
		}
	}

}

u16 cmvRegRead(XSpiPs * spiDevice, u8 addr)
{
	u8 txBuffer[] = {0x00, 0x00, 0x00};
	u8 rxBuffer[] = {0x00, 0x00, 0x00};
	u16 val = 0x0000;

	txBuffer[0] = CMV_RD_REG | (addr & CMV_ADDR_MASK);
	XSpiPs_SetSlaveSelect(spiDevice, 0x00);
	usleep(1);
	XSpiPs_PolledTransfer(spiDevice, txBuffer, rxBuffer, 3);
	usleep(1);
	XSpiPs_SetSlaveSelect(spiDevice, 0x0F);
	val = (rxBuffer[1] << 8) | rxBuffer[2];

	return val;
}

void cmvRegWrite(XSpiPs * spiDevice, u8 addr, u16 val)
{
	u8 txBuffer[] = {0x00, 0x00, 0x00};
	u8 rxBuffer[] = {0x00, 0x00, 0x00};

	txBuffer[0] = CMV_WR_REG | (addr & CMV_ADDR_MASK);
	txBuffer[1] = (val >> 8) & 0xFF;
	txBuffer[2] = val & 0xFF;
	XSpiPs_SetSlaveSelect(spiDevice, 0x00);
	usleep(1);
	XSpiPs_PolledTransfer(spiDevice, txBuffer, rxBuffer, 3);
	usleep(1);
	XSpiPs_SetSlaveSelect(spiDevice, 0x0F);
}
