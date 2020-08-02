/*
HDMI Driver

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
#include "hdmi.h"
#include "hdmi_dark_frame.h"
#include "gpio.h"
#include "frame.h"
#include "xiicps.h"
#include "camera_state.h"
#include <math.h>

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// Latency Offsets, 4K Mode
#define OPX_COUNT_IV2_OUT_OFFSET_4K		0x1000
#define OPX_COUNT_IV2_IN_OFFSET_4K		0x2FFF
#define OPX_COUNT_DC_EN_OFFFSET_4K		0x48C2

// Latency Offsets, 2K Mode
#define OPX_COUNT_IV2_OUT_OFFSET_2K		0x0800
#define OPX_COUNT_IV2_IN_OFFSET_2K		0x17F7
#define OPX_COUNT_DC_EN_OFFFSET_2K		0x24FA

// HDMI PHY I2C Device
#define IIC_DEVICE_ID		XPAR_XIICPS_1_DEVICE_ID
#define IIC_SLAVE_ADDR		0x39
#define EDID_SLAVE_ADDR		0x3F
#define IIC_SCLK_RATE		100000

// HDMI Control Register Bitfield
#define HDMI_CTRL_M00_AXI_ARM                 0x10000000
#define HDMI_CTRL_VSYNC_IF					  0x00010000

// Private Type Definitions --------------------------------------------------------------------------------------------

typedef struct
{
	// Slave Reg 0
	u32 vy0_vx0;			// vx0: Left edge of viewport w.r.t. HSYNC. Visible start: 192.
							// vy0: Top edge of viewport w.r.t. VSYNC. Visible start: 41.
	// Slave Reg 1
	u32 vyDiv_vxDiv;		// vxDiv: Viewport X scaling factor. Preview width on screen is (2^24 / vxDiv).
							// vyDiv: Viewport Y scaling factor. Match vxDiv to preserve aspect ratio.
	// Slave Reg 2
	u32 hImage2048_wHDMI;	// wHDMI: HSYNC interval. 1080p30: 2200, 1080p25: 2640, 1080p24: 2750.
							// hImage2048: Normalized aspect ratio. Preview height on screen is (2^24 / vyDiv) * (hImage2048 / 2048).
	// Slave Reg 3
	s32 q_mult_inv_HL2_LH2;		// Inverse quantizer multiplier for HL2 and LH2. Default: (65536 / q_mult_HL2_LH2).
	// Slave Reg 4
	s32 q_mult_inv_HH2;			// Inverse quantizer multiplier for HH2. Default: (65536 / q_mult_HH2).
	// Slave Reg 5
	u32 control;				// Control register for HDMI peripheral.
	// Slave Reg 6
	u16 fifo_wr_count_LL2;		// FIFO fill level for LL2 codestream.
	u16 fifo_wr_count_LH2;		// FIFO fill level for LH2 codestream.
	// Slave Reg 7
	u16 fifo_wr_count_HL2;		// FIFO fill level for HL2 codestream.
	u16 fifo_wr_count_HH2;		// FIFO fill level for HH2 codestream.
	// Slave Reg 8
	u32 dc_RAM_addr_update_LL2; // RAM address for LL2 to be loaded at next update.
	// Slave Reg 9
	u32 dc_RAM_addr_update_LH2; // RAM address for LH2 to be loaded at next update.
	// Slave Reg 10
	u32 dc_RAM_addr_update_HL2; // RAM address for HL2 to be loaded at next update.
	// Slave Reg 11
	u32 dc_RAM_addr_update_HH2; // RAM address for HH2 to be loaded at next update.
	// Slave Reg 12
	u32 bit_discard_update_LL2; // Bits to discard from the start of the LL2 codestream.
	// Slave Reg 13
	u32 bit_discard_update_LH2; // Bits to discard from the start of the LH2 codestream.
	// Slave Reg 14
	u32 bit_discard_update_HL2; // Bits to discard from the start of the HL2 codestream.
	// Slave Reg 15
	u32 bit_discard_update_HH2; // Bits to discard from the start of the HH2 codestream.
	// Slave Reg 16
	u32 opx_count_iv2_out_offset;	// Pixel latency offset at the Inverse DWT Vertical Stage 2 (IV2) output.
	// Slave Reg 17
	u32 opx_count_iv2_in_offset;	// Pixel latency offset at the Invsere DWT Vertical Stage 2 (IV2) input.
	// Slave Reg 18
	u32 opx_count_dc_en_offset;		// Pixel latency offset to trigger the decompressor enable.
	// Slave Reg 19
	u32 SS;							// 4K/2K switch.
	// Slave Reg 20
	u32 ui_control;		// Top, bottom, and pop-up UI control.
} HDMI_s;

// Private Function Prototypes -----------------------------------------------------------------------------------------

void hdmiApplyCameraStateSync(void);
void hdmiI2CWriteMasked(u8 addr, u8 data, u8 mask);
void hdmiBuildLUTs(void);
void hdmiWriteTestPattern4K(void);
void hdmiWriteTestPattern2K(void);
void hdmiResetTestPatternState(u32 wrAddr);
void hdmiPushTestPatternBits(u16 data, u8 count);

// Public Global Variables ---------------------------------------------------------------------------------------------

u32 hdmiActive = 0;

// Private Global Variables --------------------------------------------------------------------------------------------

HDMI_s * const hdmi = (HDMI_s * const) 0xA0100000;
u32 * const lutG1 =      (u32 * const) 0xA0118000;
u32 * const lutR1 =      (u32 * const) 0xA0120000;
u32 * const lutB1 =      (u32 * const) 0xA0128000;
u32 * const lutG2 =      (u32 * const) 0xA0130000;
u32 * const lut3dC30R =  (u32 * const) 0xA0138000;
u32 * const lut3dC74R =  (u32 * const) 0xA0140000;
u32 * const lut3dC30G =  (u32 * const) 0xA0148000;
u32 * const lut3dC74G =  (u32 * const) 0xA0150000;
u32 * const lut3dC30B =  (u32 * const) 0xA0158000;
u32 * const lut3dC74B =  (u32 * const) 0xA0160000;

// HDMI PHY I2C
XIicPs hdmiIic;
u8 hdmiIicTx[256];    /**< Buffer for Transmitting Data */
u8 hdmiIicRx[256];    /**< Buffer for Receiving Data */

s32 hdmiFrame = -1;

HDMI_s hdmiSync;
u32 hdmiApplyCameraStateSyncFlag = 0;

s16 gamma10[] = {0, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192, 9216, 10240, 11264, 12288, 13312, 14336, 15360};
s16 dgamma10[] = {1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024, 1024};

s16 gamma10_709range[] = {1024, 1920, 2816, 3712, 4608, 5504, 6400, 7296, 8192, 9088, 9984, 10880, 11776, 12672, 13568, 14464};
s16 dgamma10_709range[] = {896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896, 896};

s16 gamma14[] = {0, 2261, 3710, 4956, 6087, 7138, 8131, 9078, 9986, 10863, 11712, 12537, 13341, 14126, 14894, 15646};
s16 dgamma14[] = {2261, 1449, 1246, 1131, 1051, 993, 947, 908, 877, 849, 825, 804, 785, 768, 752, 738};

s16 gamma14_709range[] = {1024, 3003, 4270, 5361, 6350, 7270, 8139, 8967, 9762, 10529, 11272, 11994, 12697, 13384, 14056, 14714};
s16 dgamma14_709range[] = {1979, 1267, 1091, 989, 920, 869, 828, 795, 767, 743, 722, 703, 687, 672, 658, 646};

s16 gamma17[] = {0, 3207, 4822, 6120, 7249, 8266, 9201, 10075, 10898, 11680, 12427, 13143, 13833, 14500, 15146, 15774};
s16 dgamma17[] = {3207, 1615, 1298, 1129, 1017, 935, 874, 823, 782, 747, 716, 690, 667, 646, 628, 610};

s16 gamma17_709range[] = {1024, 3830, 5243, 6379, 7367, 8256, 9075, 9839, 10560, 11244, 11897, 12524, 13128, 13712, 14277, 14826};
s16 dgamma17_709range[] = {2806, 1413, 1136, 988, 889, 819, 764, 721, 684, 653, 627, 604, 584, 565, 549, 534};

// Interrupt Handlers --------------------------------------------------------------------------------------------------
void isrVSYNC(void * CallbackRef)
{
	FrameHeader_s fhSnapshot;
	u32 bitDiscard[4];

	XGpioPs_WritePin(&Gpio, GPIO2_PIN, 1);	// Mark ISR entry.

	hdmi->control &= ~HDMI_CTRL_VSYNC_IF;	// Clear the VSYNC interrupt flag.

	hdmiFrame = frameLastCapturedIndex();

	if(hdmiFrame >= 0)
	{
		// Take a snapshot of the frame header for the HDMI frame to be displayed, to consolidate RAM read access.
		memcpy(&fhSnapshot, frameGetHeader(hdmiFrame), sizeof(FrameHeader_s));

		// Compute the bits to be discarded for each bitfield.
		for(u8 i = 0; i < 4; i++)
		{
			bitDiscard[i] = fhSnapshot.csFIFOState[i] + ((fhSnapshot.csFIFOFlags >> (16 + i)) & 0x1) * 64;
		}

		// Load decoder RAM addresses.
		hdmi->dc_RAM_addr_update_LL2 = fhSnapshot.csAddr[0];
		hdmi->dc_RAM_addr_update_LH2 = fhSnapshot.csAddr[1];
		hdmi->dc_RAM_addr_update_HL2 = fhSnapshot.csAddr[2];
		hdmi->dc_RAM_addr_update_HH2 = fhSnapshot.csAddr[3];

		// Load the bits to be discarded.
		hdmi->bit_discard_update_LL2 = bitDiscard[0];
		hdmi->bit_discard_update_LH2 = bitDiscard[1];
		hdmi->bit_discard_update_HL2 = bitDiscard[2];
		hdmi->bit_discard_update_HH2 = bitDiscard[3];

		// Load the quantizer settings. TO-DO: Add sharpening/focus assist setting.
		hdmi->q_mult_inv_HL2_LH2 = 65536 / (fhSnapshot.q_mult_HH2_HL2_LH2 & 0xFFFF);
		hdmi->q_mult_inv_HH2 = 65536 / (fhSnapshot.q_mult_HH2_HL2_LH2 >> 16);
	}

	// Apply camera state settings to HDMI module.
	if(hdmiApplyCameraStateSyncFlag)
	{
		hdmiApplyCameraStateSync();
	}

	mainServiceTrigger();

	XGpioPs_WritePin(&Gpio, GPIO2_PIN, 0);	// Mark ISR exit.
}

// Public Function Definitions -----------------------------------------------------------------------------------------

void hdmiInit(void)
{
	// hdmiWriteTestPattern4K();
	// hdmiWriteTestPattern2K();
	hdmiDarkFrameApply(448, 2176);
	hdmiBuildLUTs();

	// Load HDMI peripheral registers with initial values.
	hdmi->q_mult_inv_HL2_LH2 = 1024;
	hdmi->q_mult_inv_HH2 = 2048;
	hdmi->dc_RAM_addr_update_LL2 = 0x20000000;
	hdmi->dc_RAM_addr_update_LH2 = 0x38000000;
	hdmi->dc_RAM_addr_update_HL2 = 0x3E000000;
	hdmi->dc_RAM_addr_update_HH2 = 0x44000000;
	hdmi->bit_discard_update_LL2 = 0;
	hdmi->bit_discard_update_LH2 = 0;
	hdmi->bit_discard_update_HL2 = 0;
	hdmi->bit_discard_update_HH2 = 0;

	hdmiApplyCameraState();
	hdmiApplyCameraStateSync();

	hdmi->ui_control = 0x000690C0;

	// Arm the AXI Master, but hold the FIFOs in reset.
	hdmi->control |= HDMI_CTRL_M00_AXI_ARM;

	// Initialize HDMI PHY I2C Device
	XIicPs_Config *Config;
	Config = XIicPs_LookupConfig(IIC_DEVICE_ID);
	XIicPs_CfgInitialize(&hdmiIic, Config, Config->BaseAddress);
	XIicPs_SetSClk(&hdmiIic, IIC_SCLK_RATE);

	// Clear buffers.
	for (int i = 0; i < 16; i++) {
		hdmiIicTx[i] = 0;
		hdmiIicRx[i] = 0;
	}
}

u32 skip = 30;
float debugMultR = 1.0f;
float debugMultG = 1.0f;
float debugMultB = 1.0f;
u32 debugGamma = 0;
u32 debugRebuildLUTs = 0;
u32 debugAdaptDarkFrame = 0;
void hdmiService(void)
{
	if(skip > 0)
	{
		skip--;
		return;
	}

	if(debugRebuildLUTs)
	{
		hdmiBuildLUTs();
		debugRebuildLUTs = 0;
	}

	if(debugAdaptDarkFrame == 1)
	{
		hdmiDarkFrameAdapt(hdmiFrame, 1024, 256);
		hdmiDarkFrameApply(448, 2176);
	}

	// Check for HPD and HDMI clock termination.
	hdmiIicTx[0] = 0x42;
	XIicPs_SetOptions(&hdmiIic,XIICPS_REP_START_OPTION);
	XIicPs_MasterSendPolled(&hdmiIic, hdmiIicTx, 1, IIC_SLAVE_ADDR);
	XIicPs_ClearOptions(&hdmiIic,XIICPS_REP_START_OPTION);
	XIicPs_MasterRecvPolled(&hdmiIic, hdmiIicRx, 1, IIC_SLAVE_ADDR);
	while (XIicPs_BusIsBusy(&hdmiIic));

	if(hdmiActive && (hdmiIicRx[0] != 0xF0))
	{
		// "Power-down the Tx."
		hdmiI2CWriteMasked(0x41, 0x40, 0x40);

		hdmiActive = 0;
	}
	else if(!hdmiActive && (hdmiIicRx[0] == 0xF0))
	{
		// "Power-up the Tx (HPD must be high)."
		hdmiI2CWriteMasked(0x41, 0x00, 0x40);

		// "Fixed register that must be set on power up."
		hdmiI2CWriteMasked(0x98, 0x03, 0xFF);
		hdmiI2CWriteMasked(0x9A, 0xE0, 0xE0);
		hdmiI2CWriteMasked(0x9C, 0x30, 0xFF);
		hdmiI2CWriteMasked(0x9D, 0x01, 0x03);
		hdmiI2CWriteMasked(0xA2, 0xA4, 0xFF);
		hdmiI2CWriteMasked(0xA3, 0xA4, 0xFF);
		hdmiI2CWriteMasked(0xE0, 0xD0, 0xFF);
		hdmiI2CWriteMasked(0xF9, 0x00, 0xFF);

		// Set aspect ratio to 16:9.
		hdmiI2CWriteMasked(0x17, 0x02, 0x02);
		// Set output mode to HDMI.
		hdmiI2CWriteMasked(0xAF, 0x02, 0x02);

		hdmiActive = 1;
	}
}

void hdmiApplyCameraState(void)
{
	float wFrame, hFrame;
	float xScale, yScale;
	float wViewport, hViewport;
	float xOffset, yOffset;
	int vx0, vy0, vxDiv, vyDiv;
	u16 hImage2048;

	wFrame = cState.cSetting[CSETTING_WIDTH]->valArray[cState.cSetting[CSETTING_WIDTH]->val].fVal;
	hFrame = cState.cSetting[CSETTING_HEIGHT]->valArray[cState.cSetting[CSETTING_HEIGHT]->val].fVal;

	if(wFrame == 4096.0f)
	{
		// 4K Mode
		hdmiSync.SS = 0;
		hdmiSync.opx_count_iv2_out_offset = OPX_COUNT_IV2_OUT_OFFSET_4K;
		hdmiSync.opx_count_iv2_in_offset = OPX_COUNT_IV2_IN_OFFSET_4K;
		hdmiSync.opx_count_dc_en_offset = OPX_COUNT_DC_EN_OFFFSET_4K;

		hImage2048 = (u16)(hFrame / 2.0f) - 4.0f;

		if(hFrame <= 2304.0f)
		{
			wViewport = 1936.0f;
			xScale = wViewport / (wFrame / 2.0f);
			yScale = xScale;
			hViewport = (hFrame / 2.0F) * yScale;
		}
		else
		{
			hViewport = 1089.0f;
			yScale = hViewport / (hFrame / 2.0f);
			xScale = yScale;
			wViewport = (wFrame / 2.0f) * xScale;
		}
	}
	else
	{
		// 2K Mode
		hdmiSync.SS = 1;
		hdmiSync.opx_count_iv2_out_offset = OPX_COUNT_IV2_OUT_OFFSET_2K;
		hdmiSync.opx_count_iv2_in_offset = OPX_COUNT_IV2_IN_OFFSET_2K;
		hdmiSync.opx_count_dc_en_offset = OPX_COUNT_DC_EN_OFFFSET_2K;
		hImage2048 = (u16)hFrame - 4.0f;

		if(hFrame <= 1152.0f)
		{
			wViewport = 1696.0f;
			xScale = wViewport / wFrame;
			yScale = xScale;
			hViewport = hFrame * yScale;
		}
		else
		{
			hViewport = 954.0f;
			yScale = hViewport / hFrame;
			xScale = yScale;
			wViewport = wFrame * xScale;
		}
	}

	// Center the viewport.
	xOffset = (1920.0f - wViewport) / 2.0f;
	yOffset = (1080.0f - hViewport) / 2.0f + 2.0f;
	vx0 = 192 + (int)xOffset;
	vy0 = 41 + (int)yOffset;
	if(vx0 < 0) { vx0 = 0; }
	else if(vx0 > 2199) {vx0 = 2199; }
	if(vy0 < 0) { vy0 = 0; }
	else if(vy0 > 1125) { vy0 = 1125; }

	// Calculate the scale factors.
	vxDiv = (int)((float)(1 << 24) / wViewport);
	vyDiv = vxDiv;
	if(vxDiv < 0x2000) { vxDiv = 0x2000; }
	else if(vxDiv > 0x4000) { vxDiv = 0x4000; }
	if(vyDiv < 0x2000) { vyDiv = 0x2000; }
	else if (vyDiv > 0x4000) { vyDiv = 0x4000; }

	hdmiSync.vy0_vx0 = ((u32)vy0 << 16) | (u32)vx0;
	hdmiSync.vyDiv_vxDiv = ((u32)vyDiv << 16) | (u32)vxDiv;
	hdmiSync.hImage2048_wHDMI = ((u32)hImage2048 << 16) | 2200;

	// Wait for the next VSYNC to apply camera settings.
	hdmiApplyCameraStateSyncFlag = 1;
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void hdmiApplyCameraStateSync(void)
{
	hdmi->SS = hdmiSync.SS;
	hdmi->opx_count_iv2_out_offset = hdmiSync.opx_count_iv2_out_offset;
	hdmi->opx_count_iv2_in_offset = hdmiSync.opx_count_iv2_in_offset;
	hdmi->opx_count_dc_en_offset = hdmiSync.opx_count_dc_en_offset;

	hdmi->vy0_vx0 = hdmiSync.vy0_vx0;
	hdmi->vyDiv_vxDiv = hdmiSync.vyDiv_vxDiv;
	hdmi->hImage2048_wHDMI = hdmiSync.hImage2048_wHDMI;

	hdmiApplyCameraStateSyncFlag = 0;
}

void hdmiI2CWriteMasked(u8 addr, u8 data, u8 mask)
{
	if(mask == 0x00) { return; }

	hdmiIicTx[0] = addr;

	if(mask != 0xFF)
	{
		XIicPs_SetOptions(&hdmiIic,XIICPS_REP_START_OPTION);
		XIicPs_MasterSendPolled(&hdmiIic, hdmiIicTx, 1, IIC_SLAVE_ADDR);
		XIicPs_ClearOptions(&hdmiIic,XIICPS_REP_START_OPTION);
		XIicPs_MasterRecvPolled(&hdmiIic, hdmiIicRx, 1, IIC_SLAVE_ADDR);
		while (XIicPs_BusIsBusy(&hdmiIic));

		data = (data & mask) | (hdmiIicRx[0] & ~mask);
	}

	hdmiIicTx[1] = data;
	XIicPs_MasterSendPolled(&hdmiIic, hdmiIicTx, 2, IIC_SLAVE_ADDR);
	while (XIicPs_BusIsBusy(&hdmiIic));
}

void hdmiBuildLUTs(void)
{
	float fR, fG, fB;
	s16 iOutG1toR, iOutG1toG, iOutG1toB;
	s16 iOutR1toR, iOutR1toG, iOutR1toB;
	s16 iOutB1toR, iOutB1toG, iOutB1toB;
	s16 iOutG2toR, iOutG2toG, iOutG2toB;
	u32 idx32L, idx32H;
	s16 * gamma;
	s16 * dgamma;

	switch(debugGamma)
	{
	case 0:
		gamma = gamma10;
		dgamma = dgamma10;
		break;
	case 1:
		gamma = gamma10_709range;
		dgamma = dgamma10_709range;
		break;
	case 2:
		gamma = gamma14;
		dgamma = dgamma14;
		break;
	case 3:
		gamma = gamma14_709range;
		dgamma = dgamma14_709range;
		break;
	case 4:
		gamma = gamma17;
		dgamma = dgamma17;
		break;
	case 5:
		gamma = gamma17_709range;
		dgamma = dgamma17_709range;
		break;
	}

	// Zero cross-axis colors.
	iOutG1toR = 0;
	iOutG1toB = 0;
	iOutR1toG = 0;
	iOutR1toB = 0;
	iOutB1toR = 0;
	iOutB1toG = 0;
	iOutG2toR = 0;
	iOutG2toB = 0;

	// Build color-mixing 1DLUTs.
	for(int iIn = 0; iIn < 4096; iIn++)
	{
		// LUT indices.
		idx32L = iIn << 1;
		idx32H = (iIn << 1) + 1;

		if(iIn < 1024)
		{
			// In-Range: Scale with saturation.
			// R
			fR = (float)iIn * debugMultR * 16.0f;
			if(fR > 16383.0f) { fR = 16383.0f; }
			else if (fR < 0.0f) { fR = 0.0f; }
			iOutR1toR = (s16) fR;

			fG = (float)iIn * debugMultG * 16.0f;
			if(fG > 16383.0f) { fG = 16383.0f; }
			else if (fG < 0.0f) { fG = 0.0f; }
			iOutG1toG = ((s16) fG) >> 1;
			iOutG2toG = ((s16) fG) >> 1;

			fB = (float)iIn * debugMultB * 16.0f;
			if(fB > 16383.0f) { fB = 16383.0f; }
			else if (fB < 0.0f) { fB = 0.0f; }
			iOutB1toB = (s16) fB;
		}
		else if(iIn < 2048)
		{
			// Clip High: 2^14 - 1
			iOutR1toR = 16383;
			iOutG1toG = 8191;
			iOutG2toG = 8191;
			iOutB1toB = 16383;
		}
		else
		{
			// Clip Low: 0
			iOutR1toR = 0;
			iOutG1toG = 0;
			iOutG2toG = 0;
			iOutB1toB = 0;
		}

		lutG1[idx32L] = (iOutG1toG << 16) | iOutG1toR;
		lutR1[idx32L] = (iOutR1toG << 16) | iOutR1toR;
		lutB1[idx32L] = (iOutB1toG << 16) | iOutB1toR;
		lutG2[idx32L] = (iOutG2toG << 16) | iOutG2toR;

		lutG1[idx32H] = iOutG1toB;
		lutR1[idx32H] = iOutR1toB;
		lutB1[idx32H] = iOutB1toB;
		lutG2[idx32H] = iOutG2toB;
	}

	// Build 3DLUT:
	s16 c0_10b, c1_10b, c2_10b, c3_10b, c4_10b, c5_10b, c6_10b, c7_10b;
	for(int b = 0; b < 16; b++)
	{
		for(int g = 0; g < 16; g++)
		{
			for(int r = 0; r < 16; r++)
			{
				// LUT Indices
				idx32L = (b << 9) + (g << 5) + (r << 1);
				idx32H = (b << 9) + (g << 5) + (r << 1) + 1;

				// Red Output
				c0_10b = gamma[r];
				c1_10b = 0;
				c2_10b = dgamma[r];
				c3_10b = 0;
				c4_10b = 0;
				c5_10b = 0;
				c6_10b = 0;
				c7_10b = 0;
				lut3dC30R[idx32L] = (c1_10b << 16) | c0_10b;
				lut3dC30R[idx32H] = (c3_10b << 16) | c2_10b;
				lut3dC74R[idx32L] = (c5_10b << 16) | c4_10b;
				lut3dC74R[idx32H] = (c7_10b << 16) | c6_10b;

				// Green Output
				c0_10b = gamma[g];
				c1_10b = 0;
				c2_10b = 0;
				c3_10b = dgamma[g];
				c4_10b = 0;
				c5_10b = 0;
				c6_10b = 0;
				c7_10b = 0;
				lut3dC30G[idx32L] = (c1_10b << 16) | c0_10b;
				lut3dC30G[idx32H] = (c3_10b << 16) | c2_10b;
				lut3dC74G[idx32L] = (c5_10b << 16) | c4_10b;
				lut3dC74G[idx32H] = (c7_10b << 16) | c6_10b;

				// Blue Output
				c0_10b = gamma[b];
				c1_10b = dgamma[b];
				c2_10b = 0;
				c3_10b = 0;
				c4_10b = 0;
				c5_10b = 0;
				c6_10b = 0;
				c7_10b = 0;
				lut3dC30B[idx32L] = (c1_10b << 16) | c0_10b;
				lut3dC30B[idx32H] = (c3_10b << 16) | c2_10b;
				lut3dC74B[idx32L] = (c5_10b << 16) | c4_10b;
				lut3dC74B[idx32H] = (c7_10b << 16) | c6_10b;
			}
		}
	}

}

void hdmiWriteTestPattern4K(void)
{
	u16 wipPixel;

	// LL2
	hdmiResetTestPatternState(0x20000000);
	for(u16 pxDiscard = 1584; pxDiscard > 0; pxDiscard--)
	{
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 10);
		}
	}
	for(u16 y = 0; y < 2*384; y++)
	{
		for(u8 x = 0; x < 32; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						if((y < 10) && (color == 0)) { wipPixel = x * 32; }
						else { wipPixel = 0; }
						hdmiPushTestPatternBits(wipPixel, 10);
					}
				}
			}
		}
	}

	// LH2
	hdmiResetTestPatternState(0x38000000);
	for(u16 pxDiscard = 1584; pxDiscard > 0; pxDiscard--)
	{
		hdmiPushTestPatternBits(0x3F, 8);
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 8);
		}
	}
	for(u16 y = 0; y < 2*384; y++)
	{
		for(u8 x = 0; x < 32; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					// Use 8-bit encoding.
					hdmiPushTestPatternBits(0x3F, 8);
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						wipPixel = 0;
						hdmiPushTestPatternBits(wipPixel, 8);
					}
				}
			}
		}
	}

	// HL2
	hdmiResetTestPatternState(0x3E000000);
	for(u16 pxDiscard = 1584; pxDiscard > 0; pxDiscard--)
	{
		hdmiPushTestPatternBits(0x3F, 8);
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 8);
		}
	}
	for(u16 y = 0; y < 2*384; y++)
	{
		for(u8 x = 0; x < 32; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					// Use 8-bit encoding.
					hdmiPushTestPatternBits(0x3F, 8);
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						wipPixel = 0;
						hdmiPushTestPatternBits(wipPixel, 8);
					}
				}
			}
		}
	}

	// HH2
	hdmiResetTestPatternState(0x44000000);
	for(u16 pxDiscard = 1584; pxDiscard > 0; pxDiscard--)
	{
		hdmiPushTestPatternBits(0x3F, 8);
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 8);
		}
	}
	for(u16 y = 0; y < 2*384; y++)
	{
		for(u8 x = 0; x < 32; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					// Use 8-bit encoding.
					hdmiPushTestPatternBits(0x3F, 8);
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						wipPixel = 0;
						hdmiPushTestPatternBits(wipPixel, 8);
					}
				}
			}
		}
	}

}

void hdmiWriteTestPattern2K(void)
{
	u16 wipPixel;

	// LL2
	hdmiResetTestPatternState(0x20000000);
	for(u16 pxDiscard = 832; pxDiscard > 0; pxDiscard--)
	{
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 10);
		}
	}
	for(u16 y = 0; y < 2*192; y++)
	{
		for(u8 x = 0; x < 16; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						if((y < 16) && (color == 0))
						{ wipPixel = 256 + (32*y) % 512; }
						else { wipPixel = 0; }
						hdmiPushTestPatternBits(wipPixel, 10);
					}
				}
			}
		}
	}

	// LH2
	hdmiResetTestPatternState(0x38000000);
	for(u16 pxDiscard = 830; pxDiscard > 0; pxDiscard--)
	{
		hdmiPushTestPatternBits(0x3F, 8);
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 8);
		}
	}
	for(u16 y = 0; y < 2*192; y++)
	{
		for(u8 x = 0; x < 16; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					// Use 8-bit encoding.
					hdmiPushTestPatternBits(0x3F, 8);
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						wipPixel = 0;
						hdmiPushTestPatternBits(wipPixel, 8);
					}
				}
			}
		}
	}

	// HL2
	hdmiResetTestPatternState(0x3E000000);
	for(u16 pxDiscard = 830; pxDiscard > 0; pxDiscard--)
	{
		hdmiPushTestPatternBits(0x3F, 8);
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 8);
		}
	}
	for(u16 y = 0; y < 2*192; y++)
	{
		for(u8 x = 0; x < 16; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					// Use 8-bit encoding.
					hdmiPushTestPatternBits(0x3F, 8);
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						wipPixel = 0;
						hdmiPushTestPatternBits(wipPixel, 8);
					}
				}
			}
		}
	}

	// HH2
	hdmiResetTestPatternState(0x44000000);
	for(u16 pxDiscard = 830; pxDiscard > 0; pxDiscard--)
	{
		hdmiPushTestPatternBits(0x3F, 8);
		for(u8 i4px = 0; i4px < 4; i4px++)
		{
			hdmiPushTestPatternBits(0x0000, 8);
		}
	}
	for(u16 y = 0; y < 2*192; y++)
	{
		for(u8 x = 0; x < 16; x++)
		{
			for(u8 color = 0; color < 4; color++)
			{
				for(u8 xLoc = 0; xLoc < 4; xLoc++)
				{
					// Use 8-bit encoding.
					hdmiPushTestPatternBits(0x3F, 8);
					for(u8 i4px = 0; i4px < 4; i4px++)
					{
						wipPixel = 0;
						hdmiPushTestPatternBits(wipPixel, 8);
					}
				}
			}
		}
	}

}

u64 wipWord;
u8 wipIndex ;
u32 * wrAddr;
void hdmiResetTestPatternState(u32 wrAddrBase)
{
	wipWord = 0x0000000000000000;
	wipIndex = 0;
	wrAddr = (u32 *)((u64) wrAddrBase);
}

void hdmiPushTestPatternBits(u16 data, u8 count)
{
	wipWord |= ((u64) data << wipIndex);
	wipIndex += count;
	if(wipIndex >= 32)
	{
		*wrAddr++ = (wipWord & 0xFFFFFFFF);
		wipWord = (wipWord >> 32);
		wipIndex -= 32;
	}
}

