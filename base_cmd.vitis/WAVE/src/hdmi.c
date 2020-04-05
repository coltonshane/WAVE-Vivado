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

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

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
	u16 vx0;			// Left edge of viewport w.r.t. HSYNC. Visible start: 192.
	u16 vy0;			// Top edge of viewport w.r.t. VSYNC. Visible start: 41.
	// Slave Reg 1
	u16 vxDiv;			// Viewport X scaling factor. Preview width on screen is (2^24 / vxDiv).
	u16 vyDiv;			// Viewport Y scaling factor. Match vxDiv to preserve aspect ratio.
	// Slave Reg 2
	u16 wHDMI;			// HSYNC interval. 1080p30: 2200, 1080p25: 2640, 1080p24: 2750.
	u16 hImage2048;		// Normalized aspect ratio. Preview height on screen is (2^24 / vyDiv) * (hImage2048 / 2048).
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
	u32 debug_shift0;	// Debug: Pixel latency offset at the Inverse DWT Vertical Stage 2 (IV2) output.
	// Slave Reg 17
	u32 debug_shift1;	// Debug: Pixel latency offset at the Invsere DWT Vertical Stage 2 (IV2) input.
	// Slave Reg 18
	u32 debug_shift2;	// Debug: Pixel latency offset to trigger the decompressor enable.
	// Slave Reg 19
	u32 debug_shift3;	// Debug: Unused.
	// Slave Reg 20
	u32 ui_control;		// Top, bottom, and pop-up UI control.
} HDMI_s;

// Private Function Prototypes -----------------------------------------------------------------------------------------

void hdmiI2CWriteMasked(u8 addr, u8 data, u8 mask);
void hdmiWriteTestPattern(void);
void hdmiResetTestPatternState(u32 wrAddr);
void hdmiPushTestPatternBits(u16 data, u8 count);

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

HDMI_s * hdmi = (HDMI_s *) 0xA0040000;
XIicPs Iic;

u8 SendBuffer[256];    /**< Buffer for Transmitting Data */
u8 RecvBuffer[256];    /**< Buffer for Receiving Data */

s32 hdmiFrame = -1;

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
	}

	cmvServiceFlag = 1;

	XGpioPs_WritePin(&Gpio, GPIO2_PIN, 0);	// Mark ISR exit.
}

// Public Function Definitions -----------------------------------------------------------------------------------------

void hdmiInit(void)
{
	hdmiWriteTestPattern();

	// Load HDMI peripheral registers with initial values.
	hdmi->vx0 = 186;
	hdmi->vy0 = 41;
	hdmi->vxDiv = 0x2133;
	hdmi->vyDiv = 0x2133;
	hdmi->wHDMI = 2200;
	hdmi->hImage2048 = 1152;
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
	hdmi->debug_shift0 = 0x1000;
	hdmi->debug_shift1 = 0x2FFF;
	hdmi->debug_shift2 = 0x48C2;
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

	// Wait for HPD and HDMI clock termination detection.
	while(RecvBuffer[0] != 0xF0)
	{
		SendBuffer[0] = 0x42;
		XIicPs_SetOptions(&Iic,XIICPS_REP_START_OPTION);
		XIicPs_MasterSendPolled(&Iic, SendBuffer, 1, IIC_SLAVE_ADDR);
		XIicPs_ClearOptions(&Iic,XIICPS_REP_START_OPTION);
		XIicPs_MasterRecvPolled(&Iic, RecvBuffer, 1, IIC_SLAVE_ADDR);
		while (XIicPs_BusIsBusy(&Iic));
	}

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
}

// Private Function Definitions ----------------------------------------------------------------------------------------

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

void hdmiWriteTestPattern(void)
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

