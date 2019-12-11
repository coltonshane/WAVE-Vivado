/*
 * CMV12000 Driver
*/

// Include Headers -----------------------------------------------------------------------------------------------------

#include "cmv12000.h"
#include "sleep.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

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

#define CMV_REG_COUNT_INIT 10
#define CMV_REG_COUNT_MODE 17

// Bit patterns for link training.
#define CMV_TP1 0x0055
#define CMV_TPC 0x0080

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// Public Global Variables ---------------------------------------------------------------------------------------------

CMV_Input_s * CMV_Input = (CMV_Input_s *) 0xA0000000;

// Private Global Variables --------------------------------------------------------------------------------------------

// Registers that are initialized to constant but non-default values.
u8 cmvRegAddrInit[] =
{
	69,
	89,
	99,
	102,
	108,
	110,
	112,
	116,
	123,
	124
};
u16 cmvRegValInit[] =
{
	2,
	32853,
	34956,
	8302,
	12381,
	12368,
	277,
	421,
	50,
	15
};

// Registers that must be written when changing modes between Normal and Subsampled.
u8 cmvRegAddrMode[] =
{
	1,
	2,
	66,
	67,
	68,
	82,
	83,
	84,
	85,
	86,
	87,
	88,
	98,
	107,
	109,
	113,
	114
};

// 10-bit Normal (Color)
u16 cmvRegValModeNormal[] =
{
	3072,
	0,
	0,
	1,
	0,		// 9 for Monochrome
	3099,
	5893,
	128,
	128,
	128,
	540,
	540,
	44812,
	11614,
	13416,
	789,
	84
};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

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

void cmvRegSetMode(XSpiPs * spiDevice)
{
	for(u8 i = 0; i < CMV_REG_COUNT_MODE; i++)
	{
		cmvRegWrite(spiDevice, cmvRegAddrMode[i], cmvRegValModeNormal[i]);
		usleep(10);
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

// Private Function Definitions ----------------------------------------------------------------------------------------
