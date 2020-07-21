/*
HDMI Driver

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
#include "gpio.h"
#include "hdmi.h"
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
#define IIC_DEVICE_ID		XPAR_XIICPS_0_DEVICE_ID
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
u32 * const lutG1 = (u32 * const) 0xA0108000;
u32 * const lutR1 = (u32 * const) 0xA0110000;
u32 * const lutB1 = (u32 * const) 0xA0118000;
u32 * const lutG2 = (u32 * const) 0xA0120000;
u32 * const lut3dC30R = (u32 * const) 0xA0128000;
u32 * const lut3dC74R = (u32 * const) 0xA0130000;
u32 * const lut3dC30G = (u32 * const) 0xA0138000;
u32 * const lut3dC74G = (u32 * const) 0xA0140000;
u32 * const lut3dC30B = (u32 * const) 0xA0148000;
u32 * const lut3dC74B = (u32 * const) 0xA0150000;
XIicPs Iic;

u8 SendBuffer[256];    /**< Buffer for Transmitting Data */
u8 RecvBuffer[256];    /**< Buffer for Receiving Data */

s32 hdmiFrame = -1;

HDMI_s hdmiSync;
u32 hdmiApplyCameraStateSyncFlag = 0;

// Interrupt Handlers --------------------------------------------------------------------------------------------------
void isrVSYNC(void * CallbackRef)
{
	FrameHeader_s fhSnapshot;
	u32 bitDiscard[4];

	XGpioPs_WritePin(&Gpio, GPIO2_PIN, 1);	// Mark ISR entry.

	hdmi->control &= ~HDMI_CTRL_VSYNC_IF;	// Clear the VSYNC interrupt flag.

	hdmiFrame = frameLastCaptured();

	if(hdmiFrame >= 0)
	{
		// Take a snapshot of the frame header for the HDMI frame to be displayed, to consolidate RAM read access.
		memcpy(&fhSnapshot, &fhBuffer[hdmiFrame], sizeof(FrameHeader_s));

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
	XIicPs_CfgInitialize(&Iic, Config, Config->BaseAddress);
	XIicPs_SetSClk(&Iic, IIC_SCLK_RATE);

	// Clear buffers.
	for (int i = 0; i < 16; i++) {
		SendBuffer[i] = 0;
		RecvBuffer[i] = 0;
	}
}

u32 skip = 30;
void hdmiService(void)
{
	if(skip > 0)
	{
		skip--;
		return;
	}

	// Check for HPD and HDMI clock termination.
	SendBuffer[0] = 0x42;
	XIicPs_SetOptions(&Iic,XIICPS_REP_START_OPTION);
	XIicPs_MasterSendPolled(&Iic, SendBuffer, 1, IIC_SLAVE_ADDR);
	XIicPs_ClearOptions(&Iic,XIICPS_REP_START_OPTION);
	XIicPs_MasterRecvPolled(&Iic, RecvBuffer, 1, IIC_SLAVE_ADDR);
	while (XIicPs_BusIsBusy(&Iic));

	if(hdmiActive && (RecvBuffer[0] != 0xF0))
	{
		// "Power-down the Tx."
		hdmiI2CWriteMasked(0x41, 0x40, 0x40);

		hdmiActive = 0;
	}
	else if(!hdmiActive && (RecvBuffer[0] == 0xF0))
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

	SendBuffer[0] = addr;

	if(mask != 0xFF)
	{
		XIicPs_SetOptions(&Iic,XIICPS_REP_START_OPTION);
		XIicPs_MasterSendPolled(&Iic, SendBuffer, 1, IIC_SLAVE_ADDR);
		XIicPs_ClearOptions(&Iic,XIICPS_REP_START_OPTION);
		XIicPs_MasterRecvPolled(&Iic, RecvBuffer, 1, IIC_SLAVE_ADDR);
		while (XIicPs_BusIsBusy(&Iic));

		data = (data & mask) | (RecvBuffer[0] & ~mask);
	}

	SendBuffer[1] = data;
	XIicPs_MasterSendPolled(&Iic, SendBuffer, 2, IIC_SLAVE_ADDR);
	while (XIicPs_BusIsBusy(&Iic));
}

void hdmiBuildLUTs(void)
{
	int iWorking = 0;
	u32 iLUTEntry;

	// Build independent color 1DLUTs:
	//    0 to 1023 is in-range, scale to 14b-normalized.
	// 1024 to 2047 is clipped high, set to 14b-normalized maximum.
	// 2048 to 4095 is assumed to be negative i.e. clipped low, set to zero.
	// 4096 to 8191 are not modified, should remained zero-initialized.
	for(int i = 0; i < 4096; i++)
	{
		if(i < 1024)
		{ iWorking = i << 4; }	// In-Range
		else if(i < 2048)
		{ iWorking = 16383; }	// Clip High: 2^14 - 1
		else
		{ iWorking = 0; }		// Clip Low: 0

		if((i % 2) == 0)
		{
			// Lower 16b Word
			iLUTEntry = iWorking & 0xFFFF;
		}
		else
		{
			// Upper 16b Word and 32b LUT Write
			iLUTEntry |= (iWorking & 0xFFFF) << 16;
			lutG1[i/2] = iLUTEntry;
			lutR1[i/2] = iLUTEntry;
			lutB1[i/2] = iLUTEntry;
			lutG2[i/2] = iLUTEntry;
		}
	}

	// Build 3DLUT:
	s16 c0_10b, c1_10b, c2_10b, c3_10b, c4_10b, c5_10b, c6_10b, c7_10b;
	u32 idx32L, idx32H;
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
				c0_10b = r * 64 * 16;
				c1_10b = 0;
				c2_10b = 1024;
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
				c0_10b = g * 64 * 16;
				c1_10b = 0;
				c2_10b = 0;
				c3_10b = 1024;
				c4_10b = 0;
				c5_10b = 0;
				c6_10b = 0;
				c7_10b = 0;
				lut3dC30G[idx32L] = (c1_10b << 16) | c0_10b;
				lut3dC30G[idx32H] = (c3_10b << 16) | c2_10b;
				lut3dC74G[idx32L] = (c5_10b << 16) | c4_10b;
				lut3dC74G[idx32H] = (c7_10b << 16) | c6_10b;

				// Blue Output
				c0_10b = b * 64 * 16;
				c1_10b = 1024;
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

