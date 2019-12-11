/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "sleep.h"

#include "xparameters.h"
#include "xgpiops.h"
#include "xuartps.h"
#include "xspips.h"
#include "xusb_ch9_storage.h"
#include "xusb_class_storage.h"
#include "xusb_wrapper.h"

#include "cmv12000.h"

// USB Stuff
// ========================================================================================
#define MEMORY_SIZE (64U * 1024U)
u8 Buffer[MEMORY_SIZE] ALIGNMENT_CACHELINE;

// USB function prototypes.
void BulkOutHandler(void *CallBackRef, u32 RequestedBytes,
							u32 BytesTxed);
void BulkInHandler(void *CallBackRef, u32 RequestedBytes,
							u32 BytesTxed);

struct Usb_DevData UsbInstance;
Usb_Config *UsbConfigPtr;

/* Buffer for virtual flash disk space. */
u8 VirtFlash[VFLASH_SIZE] __attribute__((section(".virtflash")));
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
// ========================================================================================

#define GPIO_DEVICE_ID XPAR_XGPIOPS_0_DEVICE_ID
#define GPIO1_PIN 78		// Bank 3, Pin 0, EMIO 0
#define GPIO2_PIN 79		// Bank 3, Pin 1, EMIO 1
#define GPIO3_PIN 80		// Bank 3, Pin 2, EMIO 2
#define GPIO4_PIN 81		// Bank 3, Pin 3, EMIO 3
#define LVDS_CLK_EN_PIN 82	// Bank 3, Pin 4, EMIO 4
#define PX_IN_RST_PIN 83	// Bank 3, Pin 5, EMIO 5
// Unused 84				// Bank 3, Pin 6, EMIO 6
// Unused 85				// Bank 3, Pin 7, EMIO 7
#define CMV_NRST_PIN 86		// Bank 3, Pin 8, EMIO 8
#define FRAME_REQ_PIN 87	// Bank 3, Pin 9, EMIO 9
#define T_EXP1_PIN 88		// Bank 3, Pin 10, EMIO 10
#define T_EXP2_PIN 89		// Bank 3, Pin 11, EMIO 11

#define UART0_DEVICE_ID XPAR_XUARTPS_0_DEVICE_ID

#define UART1_DEVICE_ID XPAR_XUARTPS_1_DEVICE_ID
#define UART1_PREFIX_MASK 0xF0
#define UART1_PREFIX_COMMAND 0xC0
#define UART1_PREFIX_REPLY 0xA0
#define UART1_COMMAND_EN_3V3SSD 0x01
#define UART1_COMMAND_EN_CMV 0x02
#define UART1_REPLY_ENPG_CMV 0x0E

#define SPI0_DEVICE_ID XPAR_XSPIPS_0_DEVICE_ID

XGpioPs Gpio;
XUartPs Uart0;
XUartPs Uart1;
XSpiPs Spi0;

u32 triggerShutdown = 0;
u32 requestFrames = 0;
u32 invalidateDCache = 0;
u32 updateCMVRegs = 0;
u16 cmv_Exp_time = 1152;
u16 cmv_Exp_kp1 = 80;
u16 cmv_Exp_kp2 = 8;
u16 cmv_Vtfl = 84 * 128 + 104;
u16 cmv_Number_slopes = 1;
u16 cmv_Number_frames = 1;

// Wavelet S1
u32 * debug_XX1_px_count_trig = (u32 *)(0xA0001000);
u32 * debug_core_XX1_addr  = (u32 *)(0xA0001004);
u32 * debug_core_HH1_data = (u32 *)(0xA0001010);
u32 * debug_core_HL1_data = (u32 *)(0xA0001014);
u32 * debug_core_LH1_data = (u32 *)(0xA0001018);
u32 * debug_core_LL1_data = (u32 *)(0xA000101C);

// Wavelet S2
u32 * debug_XX2_px_count_trig = (u32 *)(0xA0002000);
u32 * debug_core_XX2_addr  = (u32 *)(0xA0002004);
u32 * debug_core_HH2_data = (u32 *)(0xA0002010);
u32 * debug_core_HL2_data = (u32 *)(0xA0002014);
u32 * debug_core_LH2_data = (u32 *)(0xA0002018);
u32 * debug_core_LL2_data = (u32 *)(0xA000201C);

// Wavelet S3
u32 * debug_XX3_px_count_trig = (u32 *)(0xA0003000);
u32 * debug_core_XX3_addr  = (u32 *)(0xA0003004);
u32 * debug_core_HH3_data = (u32 *)(0xA0003010);
u32 * debug_core_HL3_data = (u32 *)(0xA0003014);
u32 * debug_core_LH3_data = (u32 *)(0xA0003018);
u32 * debug_core_LL3_data = (u32 *)(0xA000301C);

// Encoder
#define ENC_CTRL_M00_AXI_ARM                0x10000000
#define ENC_CTRL_C_RAM_ADDR_UPDATE_REQUEST  0x01000000
#define ENC_CTRL_C_RAM_ADDR_UPDATE_COMPLET  0x02000000
typedef struct __attribute__((packed))
{
	u32 c_RAM_addr[16];
	u32 c_RAM_addr_update[16];
	u32 q_mult_HH1_HL1_LH1;
	u32 q_mult_HH2_HL2_LH2;
	u32 q_mult_HH3_HL3_LH3;
	u32 control_q_mult_LL3;
	u16 debug_fifo_rd_count[16];
} Encoder_s;
Encoder_s * Encoder = (Encoder_s *)(0xA0004000);

int main()
{
	XGpioPs_Config *gpioConfig;
	XUartPs_Config *uart0Config;
	XUartPs_Config *uart1Config;
	XSpiPs_Config *spi0Config;
	u8 uart1Reply = 0x00;
	u8 cmvPowerReady = 0x00;

    init_platform();
    print("Hello World\n\r");

    gpioConfig = XGpioPs_LookupConfig(GPIO_DEVICE_ID);
    XGpioPs_CfgInitialize(&Gpio, gpioConfig, gpioConfig->BaseAddr);

    uart0Config = XUartPs_LookupConfig(UART0_DEVICE_ID);
    XUartPs_CfgInitialize(&Uart0, uart0Config, uart0Config->BaseAddress);
    XUartPs_SetBaudRate(&Uart0, 115200);

    uart1Config = XUartPs_LookupConfig(UART1_DEVICE_ID);
    XUartPs_CfgInitialize(&Uart1, uart1Config, uart1Config->BaseAddress);
    XUartPs_SetBaudRate(&Uart1, 115200);

    spi0Config = XSpiPs_LookupConfig(SPI0_DEVICE_ID);
    XSpiPs_CfgInitialize(&Spi0, spi0Config, spi0Config->BaseAddress);
    XSpiPs_SetOptions(&Spi0, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION);
    XSpiPs_SetClkPrescaler(&Spi0, XSPIPS_CLK_PRESCALE_64);
    XSpiPs_SetSlaveSelect(&Spi0, 0x0F);

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

    // Set all EMIO GPIO to output low.
    for(u32 i = GPIO1_PIN; i <= T_EXP2_PIN; i++)
    {
    	XGpioPs_SetDirectionPin(&Gpio, i, 1);
    	XGpioPs_SetOutputEnablePin(&Gpio, i, 1);
    	XGpioPs_WritePin(&Gpio, i, 0);
    }

    // Hold the pixel input blocks in reset until the LVDS clock is available.
    XGpioPs_WritePin(&Gpio, PX_IN_RST_PIN, 1);

    // Tell the supervisor to enable the CMV12000 power supplies. Wait for power good signals.
    while(!cmvPowerReady)
    {
    	XUartPs_SendByte(uart1Config->BaseAddress, UART1_PREFIX_COMMAND | UART1_COMMAND_EN_CMV);
    	usleep(10000);
    	uart1Reply = XUartPs_RecvByte(uart1Config->BaseAddress);
    	if((uart1Reply & UART1_PREFIX_MASK) == UART1_PREFIX_REPLY)
    	{
    		// Reply prefix is valid, check EN and PG flags.
    		if((uart1Reply & UART1_REPLY_ENPG_CMV) == UART1_REPLY_ENPG_CMV)
    		{
    			// EN_CMV, PG_3V9, and PG_VDD18 are all set. Okay to proceed.
    			cmvPowerReady = 0x01;
    		}
    	}
    }
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
    cmvRegSetMode(&Spi0);
    // cmvRegWrite(&Spi0, CMV_REG_ADDR_TEST_PATTERN, CMV_REG_VAL_TEST_PATTERN_ON);
    // cmvRegWrite(&Spi0, CMV_REG_ADDR_DIG_GAIN, 16);

    usleep(1000);

    // Configure the Encoder and arm the AXI Master.
    Encoder->q_mult_HH1_HL1_LH1 = 0x00100020;
    Encoder->q_mult_HH2_HL2_LH2 = 0x00200040;
    Encoder->q_mult_HH3_HL3_LH3 = 0x00400040;
    Encoder->c_RAM_addr_update[0] = 0x20000000;  // HH1.R1
    Encoder->c_RAM_addr_update[1] = 0x24000000;  // HH1.G1
    Encoder->c_RAM_addr_update[2] = 0x28000000;  // HH1.G2
    Encoder->c_RAM_addr_update[3] = 0x2C000000;  // HH1.B1
    Encoder->c_RAM_addr_update[4] = 0x30000000;  // HL1.R1
    Encoder->c_RAM_addr_update[5] = 0x34000000;  // HL1.G1
    Encoder->c_RAM_addr_update[6] = 0x38000000;  // HL1.G2
    Encoder->c_RAM_addr_update[7] = 0x3C000000;  // HL1.B1
    Encoder->c_RAM_addr_update[8] = 0x40000000;  // LH1.R1
    Encoder->c_RAM_addr_update[9] = 0x44000000;  // LH1.G1
    Encoder->c_RAM_addr_update[10] = 0x48000000; // LH1.G2
    Encoder->c_RAM_addr_update[11] = 0x4C000000; // LH1.B1
    Encoder->c_RAM_addr_update[12] = 0x50000000; // HH2
    Encoder->c_RAM_addr_update[13] = 0x58000000; // HL2
    Encoder->c_RAM_addr_update[14] = 0x60000000; // LH2
    Encoder->c_RAM_addr_update[15] = 0x68000000; // XX3
    Encoder->control_q_mult_LL3 = ENC_CTRL_M00_AXI_ARM | 0x00000100;

    Usb_Start(UsbInstance.PrivateData);

    while(!triggerShutdown)
    {
    	UsbPollHandler(UsbInstance.PrivateData);

    	while(requestFrames)
    	{
    		// Toggle the frame request pin.
    		XGpioPs_WritePin(&Gpio, FRAME_REQ_PIN, 1);
    		usleep(1);
    		XGpioPs_WritePin(&Gpio, FRAME_REQ_PIN, 0);
    		requestFrames = 0;
    	}

    	if(updateCMVRegs)
    	{
    		updateCMVRegs = 0;
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_EXP_TIME_L, cmv_Exp_time);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_EXP_KP1_L, cmv_Exp_kp1);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_EXP_KP2_L, cmv_Exp_kp2);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_VTFL, cmv_Vtfl);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_NUMBER_SLOPES, cmv_Number_slopes);
    	    cmvRegWrite(&Spi0, CMV_REG_ADDR_NUMBER_FRAMES, cmv_Number_frames);
    	}

    	if(invalidateDCache)
    	{
    		invalidateDCache = 0;
    		Xil_DCacheInvalidate();
    	}
    }

    cleanup_platform();
    return 0;
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

