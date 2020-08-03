/*
WAVE Bootloader USB Mass Storage Device Driver

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

#include "usb.h"
#include "xusb_ch9_storage.h"
#include "xusb_class_storage.h"
#include "xusb_wrapper.h"
#include "xiicps.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

// FUSB302 I2C Device
#define IIC_DEVICE_ID		XPAR_XIICPS_0_DEVICE_ID
#define IIC_SLAVE_ADDR		0x22
#define IIC_SCLK_RATE		100000

// GT Lane 0 Initialization
#define SERDES_PLL_REF_SEL0_OFFSET                                                 0XFD410000
#define SERDES_L0_L0_REF_CLK_SEL_OFFSET                                            0XFD402860
#define SERDES_L0_TM_PLL_DIG_37_OFFSET                                             0XFD402094
#define SERDES_L0_PLL_SS_STEPS_0_LSB_OFFSET                                        0XFD402368
#define SERDES_L0_PLL_SS_STEPS_1_MSB_OFFSET                                        0XFD40236C
#define SERDES_L0_PLL_SS_STEP_SIZE_0_LSB_OFFSET                                    0XFD402370
#define SERDES_L0_PLL_SS_STEP_SIZE_1_OFFSET                                        0XFD402374
#define SERDES_L0_PLL_SS_STEP_SIZE_2_OFFSET                                        0XFD402378
#define SERDES_L0_PLL_SS_STEP_SIZE_3_MSB_OFFSET                                    0XFD40237C
#define SERDES_L0_TM_DIG_6_OFFSET                                                  0XFD40106C
#define SERDES_L0_TX_DIG_TM_61_OFFSET                                              0XFD4000F4
#define SERDES_L0_TM_AUX_0_OFFSET                                                  0XFD4010CC
#define SERDES_L0_TM_MISC2_OFFSET                                                  0XFD40189C
#define SERDES_L0_TM_IQ_ILL1_OFFSET                                                0XFD4018F8
#define SERDES_L0_TM_IQ_ILL2_OFFSET                                                0XFD4018FC
#define SERDES_L0_TM_ILL12_OFFSET                                                  0XFD401990
#define SERDES_L0_TM_E_ILL1_OFFSET                                                 0XFD401924
#define SERDES_L0_TM_E_ILL2_OFFSET                                                 0XFD401928
#define SERDES_L0_TM_IQ_ILL3_OFFSET                                                0XFD401900
#define SERDES_L0_TM_E_ILL3_OFFSET                                                 0XFD40192C
#define SERDES_L0_TM_ILL8_OFFSET                                                   0XFD401980
#define SERDES_L0_TM_IQ_ILL8_OFFSET                                                0XFD401914
#define SERDES_L0_TM_IQ_ILL9_OFFSET                                                0XFD401918
#define SERDES_L0_TM_E_ILL8_OFFSET                                                 0XFD401940
#define SERDES_L0_TM_E_ILL9_OFFSET                                                 0XFD401944

// GT Lane 1 Initialization
#define SERDES_PLL_REF_SEL1_OFFSET                                                 0XFD410004
#define SERDES_L0_L1_REF_CLK_SEL_OFFSET                                            0XFD402864
#define SERDES_L1_TM_PLL_DIG_37_OFFSET                                             0XFD406094
#define SERDES_L1_PLL_SS_STEPS_0_LSB_OFFSET                                        0XFD406368
#define SERDES_L1_PLL_SS_STEPS_1_MSB_OFFSET                                        0XFD40636C
#define SERDES_L1_PLL_SS_STEP_SIZE_0_LSB_OFFSET                                    0XFD406370
#define SERDES_L1_PLL_SS_STEP_SIZE_1_OFFSET                                        0XFD406374
#define SERDES_L1_PLL_SS_STEP_SIZE_2_OFFSET                                        0XFD406378
#define SERDES_L1_PLL_SS_STEP_SIZE_3_MSB_OFFSET                                    0XFD40637C
#define SERDES_L1_TM_DIG_6_OFFSET                                                  0XFD40506C
#define SERDES_L1_TX_DIG_TM_61_OFFSET                                              0XFD4040F4
#define SERDES_L1_TM_AUX_0_OFFSET                                                  0XFD4050CC
#define SERDES_L1_TM_MISC2_OFFSET                                                  0XFD40589C
#define SERDES_L1_TM_IQ_ILL1_OFFSET                                                0XFD4058F8
#define SERDES_L1_TM_IQ_ILL2_OFFSET                                                0XFD4058FC
#define SERDES_L1_TM_ILL12_OFFSET                                                  0XFD405990
#define SERDES_L1_TM_E_ILL1_OFFSET                                                 0XFD405924
#define SERDES_L1_TM_E_ILL2_OFFSET                                                 0XFD405928
#define SERDES_L1_TM_IQ_ILL3_OFFSET                                                0XFD405900
#define SERDES_L1_TM_E_ILL3_OFFSET                                                 0XFD40592C
#define SERDES_L1_TM_ILL8_OFFSET                                                   0XFD405980
#define SERDES_L1_TM_IQ_ILL8_OFFSET                                                0XFD405914
#define SERDES_L1_TM_IQ_ILL9_OFFSET                                                0XFD405918
#define SERDES_L1_TM_E_ILL8_OFFSET                                                 0XFD405940
#define SERDES_L1_TM_E_ILL9_OFFSET                                                 0XFD405944

#define SERDES_ICM_CFG0_OFFSET                                                     0XFD410010

// TO-DO: What even is this? It gets passed to a dead-end function. Redefining to minimal size.
// #define MEMORY_SIZE (64U * 1024U)
#define MEMORY_SIZE 64U

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

// USB function prototypes.
void usbInitLane0(void);
void usbInitLane1(void);
void usbPSU_Mask_Write(unsigned long offset, unsigned long mask, unsigned long val);
void usbI2CWriteMasked(u8 addr, u8 data, u8 mask);

void BulkOutHandler(void *CallBackRef, u32 RequestedBytes,
							u32 BytesTxed);
void BulkInHandler(void *CallBackRef, u32 RequestedBytes,
							u32 BytesTxed);

// Public Global Variables ---------------------------------------------------------------------------------------------

u8 VirtFlash[VFLASH_SIZE] ALIGNMENT_CACHELINE;

// Private Global Variables --------------------------------------------------------------------------------------------

struct Usb_DevData UsbInstance;
Usb_Config *UsbConfigPtr;

// FUSB302 I2C
XIicPs usbIic;
u8 usbIicTx[256];    /**< Buffer for Transmitting Data */
u8 usbIicRx[256];    /**< Buffer for Receiving Data */

// Scratch Buffer (OCM)
u8 Buffer[MEMORY_SIZE] ALIGNMENT_CACHELINE;

USB_CBW CBW ALIGNMENT_CACHELINE;
USB_CSW CSW ALIGNMENT_CACHELINE;

u8	Phase;
u32	rxBytesLeft;
u8	*VirtFlashWritePointer = VirtFlash;

/* Initialize a DFU data structure */
static USBCH9_DATA storage_data = {
		.ch9_func = {
				/* Set the chapter9 hooks */
				.Usb_Ch9SetupDevDescReply =
						Usb_Ch9SetupDevDescReply,
				.Usb_Ch9SetupCfgDescReply =
						Usb_Ch9SetupCfgDescReply,
				.Usb_Ch9SetupBosDescReply =
						Usb_Ch9SetupBosDescReply,
				.Usb_Ch9SetupStrDescReply =
						Usb_Ch9SetupStrDescReply,
				.Usb_SetConfiguration =
						Usb_SetConfiguration,
				.Usb_SetConfigurationApp =
						Usb_SetConfigurationApp,
				/* hook the set interface handler */
				.Usb_SetInterfaceHandler = NULL,
				/* hook up storage class handler */
				.Usb_ClassReq = ClassReq,
				.Usb_GetDescReply = NULL,
		},
		.data_ptr = (void *)NULL,
};

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void usbInit(void)
{
	// Initialize both GT Lane 0 and GT Lane 1.
	// usbInitLane0();
	// usbInitLane1();

	// TO-DO: Select active GT Lane based on CC levels.
	// usbPSU_Mask_Write(SERDES_ICM_CFG0_OFFSET, 0x00000077U, 0x00000003U);

	// Initialize FUSB302 I2C Device and set CC1 pull-down only.
	XIicPs_Config *Config;
	Config = XIicPs_LookupConfig(IIC_DEVICE_ID);
	XIicPs_CfgInitialize(&usbIic, Config, Config->BaseAddress);
	XIicPs_SetSClk(&usbIic, IIC_SCLK_RATE);
	usbI2CWriteMasked(0x02, 0x03, 0x03);

	UsbConfigPtr = LookupConfig(USB_DEVICE_ID);
	CfgInitialize(&UsbInstance, UsbConfigPtr, UsbConfigPtr->BaseAddress);

	Set_Ch9Handler(UsbInstance.PrivateData, Ch9Handler);
	Set_DrvData(UsbInstance.PrivateData, &storage_data);
	EpConfigure(UsbInstance.PrivateData, 1U, USB_EP_DIR_OUT, USB_EP_TYPE_BULK);
	EpConfigure(UsbInstance.PrivateData, 1U, USB_EP_DIR_IN, USB_EP_TYPE_BULK);
	ConfigureDevice(UsbInstance.PrivateData, Buffer, MEMORY_SIZE);
	SetEpHandler(UsbInstance.PrivateData, 1U, USB_EP_DIR_OUT, BulkOutHandler);
	SetEpHandler(UsbInstance.PrivateData, 1U, USB_EP_DIR_IN, BulkInHandler);
	UsbEnableEvent(UsbInstance.PrivateData, XUSBPSU_DEVTEN_EVNTOVERFLOWEN |
						 	 	 	 	 	XUSBPSU_DEVTEN_WKUPEVTEN |
											XUSBPSU_DEVTEN_ULSTCNGEN |
											XUSBPSU_DEVTEN_CONNECTDONEEN |
											XUSBPSU_DEVTEN_USBRSTEN |
											XUSBPSU_DEVTEN_DISCONNEVTEN);

	// Defer start until after file system is created.
	// Usb_Start(UsbInstance.PrivateData);
}

void usbStart(void)
{
	XUsbPsu_Start(UsbInstance.PrivateData);
}

void usbStop(void)
{
	XUsbPsu_Stop(UsbInstance.PrivateData);
}

void usbPoll(void)
{
	UsbPollHandler(UsbInstance.PrivateData);
}

// Private Function Definitions ----------------------------------------------------------------------------------------

void usbInitLane0(void)
{
	usbPSU_Mask_Write(SERDES_PLL_REF_SEL0_OFFSET, 0x0000001FU, 0x0000000DU);
	usbPSU_Mask_Write(SERDES_L0_L0_REF_CLK_SEL_OFFSET, 0x00000084U, 0x00000004U);
	usbPSU_Mask_Write(SERDES_L0_TM_PLL_DIG_37_OFFSET, 0x00000010U, 0x00000010U);
	usbPSU_Mask_Write(SERDES_L0_PLL_SS_STEPS_0_LSB_OFFSET, 0x000000FFU, 0x00000022U);
	usbPSU_Mask_Write(SERDES_L0_PLL_SS_STEPS_1_MSB_OFFSET, 0x00000007U, 0x00000004U);
	usbPSU_Mask_Write(SERDES_L0_PLL_SS_STEP_SIZE_0_LSB_OFFSET, 0x000000FFU, 0x000000EDU);
	usbPSU_Mask_Write(SERDES_L0_PLL_SS_STEP_SIZE_1_OFFSET, 0x000000FFU, 0x00000055U);
	usbPSU_Mask_Write(SERDES_L0_PLL_SS_STEP_SIZE_2_OFFSET, 0x000000FFU, 0x00000001U);
	usbPSU_Mask_Write(SERDES_L0_PLL_SS_STEP_SIZE_3_MSB_OFFSET, 0x00000033U, 0x00000030U);
	usbPSU_Mask_Write(SERDES_L0_TM_DIG_6_OFFSET, 0x00000003U, 0x00000003U);
	usbPSU_Mask_Write(SERDES_L0_TX_DIG_TM_61_OFFSET, 0x00000003U, 0x00000003U);
	usbPSU_Mask_Write(SERDES_L0_TM_AUX_0_OFFSET, 0x00000020U, 0x00000020U);
	usbPSU_Mask_Write(SERDES_L0_TM_MISC2_OFFSET, 0x00000080U, 0x00000080U);
	usbPSU_Mask_Write(SERDES_L0_TM_IQ_ILL1_OFFSET, 0x000000FFU, 0x00000064U);
	usbPSU_Mask_Write(SERDES_L0_TM_IQ_ILL2_OFFSET, 0x000000FFU, 0x00000064U);
	usbPSU_Mask_Write(SERDES_L0_TM_ILL12_OFFSET, 0x000000FFU, 0x00000010U);
	usbPSU_Mask_Write(SERDES_L0_TM_E_ILL1_OFFSET, 0x000000FFU, 0x000000FEU);
	usbPSU_Mask_Write(SERDES_L0_TM_E_ILL2_OFFSET, 0x000000FFU, 0x00000000U);
	usbPSU_Mask_Write(SERDES_L0_TM_IQ_ILL3_OFFSET, 0x000000FFU, 0x00000064U);
	usbPSU_Mask_Write(SERDES_L0_TM_E_ILL3_OFFSET, 0x000000FFU, 0x00000000U);
	usbPSU_Mask_Write(SERDES_L0_TM_ILL8_OFFSET, 0x000000FFU, 0x000000FFU);
	usbPSU_Mask_Write(SERDES_L0_TM_IQ_ILL8_OFFSET, 0x000000FFU, 0x000000F7U);
	usbPSU_Mask_Write(SERDES_L0_TM_IQ_ILL9_OFFSET, 0x00000001U, 0x00000001U);
	usbPSU_Mask_Write(SERDES_L0_TM_E_ILL8_OFFSET, 0x000000FFU, 0x000000F7U);
	usbPSU_Mask_Write(SERDES_L0_TM_E_ILL9_OFFSET, 0x00000001U, 0x00000001U);
}

void usbInitLane1(void)
{
	usbPSU_Mask_Write(SERDES_PLL_REF_SEL1_OFFSET, 0x0000001FU, 0x0000000DU);
	usbPSU_Mask_Write(SERDES_L0_L1_REF_CLK_SEL_OFFSET, 0x00000084U, 0x00000004U);
	usbPSU_Mask_Write(SERDES_L1_TM_PLL_DIG_37_OFFSET, 0x00000010U, 0x00000010U);
	usbPSU_Mask_Write(SERDES_L1_PLL_SS_STEPS_0_LSB_OFFSET, 0x000000FFU, 0x00000022U);
	usbPSU_Mask_Write(SERDES_L1_PLL_SS_STEPS_1_MSB_OFFSET, 0x00000007U, 0x00000004U);
	usbPSU_Mask_Write(SERDES_L1_PLL_SS_STEP_SIZE_0_LSB_OFFSET, 0x000000FFU, 0x000000EDU);
	usbPSU_Mask_Write(SERDES_L1_PLL_SS_STEP_SIZE_1_OFFSET, 0x000000FFU, 0x00000055U);
	usbPSU_Mask_Write(SERDES_L1_PLL_SS_STEP_SIZE_2_OFFSET, 0x000000FFU, 0x00000001U);
	usbPSU_Mask_Write(SERDES_L1_PLL_SS_STEP_SIZE_3_MSB_OFFSET, 0x00000033U, 0x00000030U);
	usbPSU_Mask_Write(SERDES_L1_TM_DIG_6_OFFSET, 0x00000003U, 0x00000003U);
	usbPSU_Mask_Write(SERDES_L1_TX_DIG_TM_61_OFFSET, 0x00000003U, 0x00000003U);
	usbPSU_Mask_Write(SERDES_L1_TM_AUX_0_OFFSET, 0x00000020U, 0x00000020U);
	usbPSU_Mask_Write(SERDES_L1_TM_MISC2_OFFSET, 0x00000080U, 0x00000080U);
	usbPSU_Mask_Write(SERDES_L1_TM_IQ_ILL1_OFFSET, 0x000000FFU, 0x00000064U);
	usbPSU_Mask_Write(SERDES_L1_TM_IQ_ILL2_OFFSET, 0x000000FFU, 0x00000064U);
	usbPSU_Mask_Write(SERDES_L1_TM_ILL12_OFFSET, 0x000000FFU, 0x00000010U);
	usbPSU_Mask_Write(SERDES_L1_TM_E_ILL1_OFFSET, 0x000000FFU, 0x000000FEU);
	usbPSU_Mask_Write(SERDES_L1_TM_E_ILL2_OFFSET, 0x000000FFU, 0x00000000U);
	usbPSU_Mask_Write(SERDES_L1_TM_IQ_ILL3_OFFSET, 0x000000FFU, 0x00000064U);
	usbPSU_Mask_Write(SERDES_L1_TM_E_ILL3_OFFSET, 0x000000FFU, 0x00000000U);
	usbPSU_Mask_Write(SERDES_L1_TM_ILL8_OFFSET, 0x000000FFU, 0x000000FFU);
	usbPSU_Mask_Write(SERDES_L1_TM_IQ_ILL8_OFFSET, 0x000000FFU, 0x000000F7U);
	usbPSU_Mask_Write(SERDES_L1_TM_IQ_ILL9_OFFSET, 0x00000001U, 0x00000001U);
	usbPSU_Mask_Write(SERDES_L1_TM_E_ILL8_OFFSET, 0x000000FFU, 0x000000F7U);
	usbPSU_Mask_Write(SERDES_L1_TM_E_ILL9_OFFSET, 0x00000001U, 0x00000001U);
}

void usbPSU_Mask_Write(unsigned long offset, unsigned long mask, unsigned long val)
{
	unsigned long RegVal = 0x0;

	RegVal = Xil_In32(offset);
	RegVal &= ~(mask);
	RegVal |= (val & mask);
	Xil_Out32(offset, RegVal);
}

void usbI2CWriteMasked(u8 addr, u8 data, u8 mask)
{
	if(mask == 0x00) { return; }

	usbIicTx[0] = addr;

	if(mask != 0xFF)
	{
		// XIicPs_SetOptions(&Iic,XIICPS_REP_START_OPTION);
		XIicPs_MasterSendPolled(&usbIic, usbIicTx, 1, IIC_SLAVE_ADDR);
		// XIicPs_ClearOptions(&Iic,XIICPS_REP_START_OPTION);
		XIicPs_MasterRecvPolled(&usbIic, usbIicRx, 1, IIC_SLAVE_ADDR);
		while (XIicPs_BusIsBusy(&usbIic));

		data = (data & mask) | (usbIicRx[0] & ~mask);
	}

	usbIicTx[1] = data;
	XIicPs_MasterSendPolled(&usbIic, usbIicTx, 2, IIC_SLAVE_ADDR);
	while (XIicPs_BusIsBusy(&usbIic));
}

/****************************************************************************/
/**
* This function is Bulk Out Endpoint handler/Callback called by driver when
* data is received.
*
* @param	CallBackRef is pointer to Usb_DevData instance.
* @param	RequestedBytes is number of bytes requested for reception.
* @param	BytesTxed is actual number of bytes received from Host.
*
* @return	None
*
* @note		None.
*
*****************************************************************************/
void BulkOutHandler(void *CallBackRef, u32 RequestedBytes,
							u32 BytesTxed)
{
	struct Usb_DevData *InstancePtr = CallBackRef;

	if (Phase == USB_EP_STATE_COMMAND) {
		ParseCBW(InstancePtr);
	} else if (Phase == USB_EP_STATE_DATA_OUT) {
		/* WRITE command */
		switch (CBW.CBWCB[0U]) {
		case USB_RBC_WRITE:
			VirtFlashWritePointer += BytesTxed;
			rxBytesLeft -= BytesTxed;
			break;
		default:
			break;
		}
		SendCSW(InstancePtr, 0U);
	}
}

/****************************************************************************/
/**
* This function is Bulk In Endpoint handler/Callback called by driver when
* data is sent.
*
* @param	CallBackRef is pointer to Usb_DevData instance.
* @param	RequestedBytes is number of bytes requested to send.
* @param	BytesTxed is actual number of bytes sent to Host.
*
* @return	None
*
* @note		None.
*
*****************************************************************************/
void BulkInHandler(void *CallBackRef, u32 RequestedBytes,
						   u32 BytesTxed)
{
	struct Usb_DevData *InstancePtr = CallBackRef;

	if (Phase == USB_EP_STATE_DATA_IN) {
		/* Send the status */
		SendCSW(InstancePtr, 0U);
	} else if (Phase == USB_EP_STATE_STATUS) {
		Phase = USB_EP_STATE_COMMAND;
		/* Receive next CBW */
		EpBufferRecv(InstancePtr->PrivateData, 1U,
							(u8*)&CBW, sizeof(CBW));
	}
}
