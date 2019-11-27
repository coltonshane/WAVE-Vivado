/******************************************************************************
*
* Copyright (C) 2019 Xilinx, Inc.  All rights reserved.
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
*******************************************************************************/
/******************************************************************************/
/**
* @file xdmapcie_rc_enumerate_example.c
*
* This file contains a design example for using XDMA PCIe IP and its driver.
* This is an example to show the usage of driver APIs when XDMA PCIe IP is
* configured as a Root Port.
*
* The example initializes the XDMA PCIe IP and shows how to enumerate the PCIe
* system.
*
* @note
*
* This example should be used only when XDMA PCIe IP is configured as
* root complex.
*
* This code will illustrate how the XDmaPcie IP and its standalone driver can
* be used to:
*	- Initialize a XDMA PCIe IP core built as a root complex
*	- Enumerate PCIe end points in the system
*	- Assign BARs to end points
*	- find capabilities on end point
*
* Please note that this example enumerates and initializes PCIe end points
* only.
*
* We tried to use as much of the driver's API calls as possible to show the
* reader how each call could be used and that probably made the example not
* the shortest way of doing the tasks shown as they could be done.
*
*<pre>
* MODIFICATION HISTORY:
*
* Ver   Who  Date     Changes
* ----- ---- -------- ---------------------------------------------------
* 1.0	tk	01/30/2019	Initial version of XDMA PCIe root complex example
*</pre>
*****************************************************************************/

/***************************** Include Files ********************************/

#include "xparameters.h"	/* Defines for XPAR constants */
#include "xdmapcie.h"		/* XDmaPcie level 1 interface */
#include "xgpiops.h"
#include "xuartps.h"
#include "stdio.h"
#include "xil_printf.h"
#include "sleep.h"
#include "nvme.h"
#include "xtime_l.h"
#include "ff.h"

/************************** Constant Definitions ****************************/

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
#define UART1_REPLY_ENPG_SSD 0x01

XGpioPs Gpio;
XUartPs Uart0;
XUartPs Uart1;

/* Parameters for the waiting for link up routine */
#define XDMAPCIE_LINK_WAIT_MAX_RETRIES 		10
#define XDMAPCIE_LINK_WAIT_USLEEP_MIN 		90000

#define XDMAPCIE_DEVICE_ID 	XPAR_XDMAPCIE_0_DEVICE_ID

/*
 * Command register offsets
 */
#define PCIE_CFG_CMD_IO_EN	0x00000001 /* I/O access enable */
#define PCIE_CFG_CMD_MEM_EN	0x00000002 /* Memory access enable */
#define PCIE_CFG_CMD_BUSM_EN	0x00000004 /* Bus master enable */
#define PCIE_CFG_CMD_PARITY	0x00000040 /* parity errors response */
#define PCIE_CFG_CMD_SERR_EN	0x00000100 /* SERR report enable */

/*
 * PCIe Configuration registers offsets
 */

#define PCIE_CFG_ID_REG			0x0000 /* Vendor ID/Device ID offset */
#define PCIE_CFG_CMD_STATUS_REG		0x0001 /*
						* Command/Status Register
						* Offset
						*/
#define PCIE_CFG_PRI_SEC_BUS_REG	0x0006 /*
						* Primary/Sec.Bus Register
						* Offset
						*/
#define PCIE_CFG_CAH_LAT_HD_REG		0x0003 /*
						* Cache Line/Latency Timer/
						* Header Type/
						* BIST Register Offset
						*/
#define PCIE_CFG_BAR_0_REG		0x0004 /* PCIe Base Addr 0 */

#define PCIE_CFG_FUN_NOT_IMP_MASK	0xFFFF
#define PCIE_CFG_HEADER_TYPE_MASK	0x00EF0000
#define PCIE_CFG_MUL_FUN_DEV_MASK	0x00800000

#define PCIE_CFG_MAX_NUM_OF_BUS		256
#define PCIE_CFG_MAX_NUM_OF_DEV		1
#define PCIE_CFG_MAX_NUM_OF_FUN		8

#define PCIE_CFG_PRIM_SEC_BUS		0x00070100
#define PCIE_CFG_BAR_0_ADDR		0x00001111



/**************************** Type Definitions ******************************/


/***************** Macros (Inline Functions) Definitions ********************/


/************************** Function Prototypes *****************************/

int PcieInitRootComplex(XDmaPcie *XdmaPciePtr, u16 DeviceId);
u32 testRawWrite(u32 num, u32 size);
u32 testRawRead(u32 num, u32 size);

/************************** Variable Definitions ****************************/

/* Allocate PCIe Root Complex IP Instance */
XDmaPcie XdmaPcieInstance;

/****************************************************************************/
/**
* This function is the entry point for PCIe Root Complex Enumeration Example
*
* @param 	None
*
* @return
*		- XST_SUCCESS if successful
*		- XST_FAILURE if unsuccessful.
*
* @note 	None.
*
*****************************************************************************/
int main(void)
{
	XGpioPs_Config *gpioConfig;
	XUartPs_Config *uart0Config;
	XUartPs_Config *uart1Config;
	u8 uart1Reply = 0x00;
	u8 ssdPowerReady = 0x00;
	u32 pcieStatus;
	u32 nvmeStatus;

	u32 intResult;
	char strResult[128];

	/* WAVE v0.1 Board-Specific GPIO, UART, and Power Supply Initialization */
	gpioConfig = XGpioPs_LookupConfig(GPIO_DEVICE_ID);
	XGpioPs_CfgInitialize(&Gpio, gpioConfig, gpioConfig->BaseAddr);

	uart0Config = XUartPs_LookupConfig(UART0_DEVICE_ID);
	XUartPs_CfgInitialize(&Uart0, uart0Config, uart0Config->BaseAddress);
	XUartPs_SetBaudRate(&Uart0, 115200);

	uart1Config = XUartPs_LookupConfig(UART1_DEVICE_ID);
	XUartPs_CfgInitialize(&Uart1, uart1Config, uart1Config->BaseAddress);
	XUartPs_SetBaudRate(&Uart1, 115200);

	// Set all EMIO GPIO to output low.
	for(u32 i = GPIO1_PIN; i <= T_EXP2_PIN; i++)
	{
	 	XGpioPs_SetDirectionPin(&Gpio, i, 1);
	   	XGpioPs_SetOutputEnablePin(&Gpio, i, 1);
	   	XGpioPs_WritePin(&Gpio, i, 0);
	}

	// Hold the pixel input blocks in reset until the LVDS clock is available.
	XGpioPs_WritePin(&Gpio, PX_IN_RST_PIN, 1);

	// Tell the supervisor to enable the SSD power supply.
	while(!ssdPowerReady)
	{
	   	XUartPs_SendByte(uart1Config->BaseAddress, UART1_PREFIX_COMMAND | UART1_COMMAND_EN_3V3SSD);
	   	usleep(10000);
	   	uart1Reply = XUartPs_RecvByte(uart1Config->BaseAddress);
	   	if((uart1Reply & UART1_PREFIX_MASK) == UART1_PREFIX_REPLY)
	  	{
	   		// Reply prefix is valid, check EN and PG flags.
	   		if((uart1Reply & UART1_REPLY_ENPG_SSD) == UART1_REPLY_ENPG_SSD)
	   		{
	   			// EN_SSD is set, no PG flags to check. Okay to proceed.
	   			ssdPowerReady = 0x01;
	   		}
	   	}
	}
	usleep(1000);

	/* Initialize Root Complex */
	pcieStatus = PcieInitRootComplex(&XdmaPcieInstance, XDMAPCIE_DEVICE_ID);
	if (pcieStatus != XST_SUCCESS) {
		xil_printf("XdmaPcie rc enumerate Example Failed\r\n");
		return XST_FAILURE;
	}

	/* Scan PCIe Fabric */
	XDmaPcie_EnumerateFabric(&XdmaPcieInstance);
	xil_printf("Successfully ran XdmaPcie rc enumerate Example\r\n");

	/* NVMe Initialize */
	nvmeStatus = nvmeInit();
	if (nvmeStatus == NVME_OK) {
		xil_printf("NVMe initialization successful. PCIe link is Gen3 x4.\r\n");
	} else {
		sprintf(strResult, "NVMe driver failed to initialize. Error Code: %8x\r\n", nvmeStatus);
		xil_printf(strResult);
		if(nvmeStatus == NVME_ERROR_PHY) {
			xil_printf("PCIe link must be Gen3 x4 for this example.\r\n");
		}
		return XST_FAILURE;
	}
	xil_printf("10s delay for SSD...\r\n");
	usleep(10000000);

	/* NVMe Raw R/W Test */
	/*
	u32 num = 0x10000;		// Number of blocks to read/write.
	u32 size = 0x100000;	// Block size in [B] (max 1MiB).;

	sprintf(strResult, "Writing %d blocks of %d bytes...\r\n", num, size);
	xil_printf(strResult);
	intResult = testRawWrite(num, size);
	sprintf(strResult, "Write Time [ms]: %d\r\n", intResult);
	xil_printf(strResult);

	xil_printf("10s delay for SSD...\r\n");
	usleep(10000000);

	sprintf(strResult, "Reading %d blocks of %d bytes...\r\n", num, size);
	xil_printf(strResult);
	intResult = testRawRead(num, size);
	sprintf(strResult, "Read Time [ms]: %d\r\n", intResult);
	xil_printf(strResult);
	*/

	/* NVMe FatFs Write Test */
	FATFS fs;
	FIL fil;
	FRESULT res;
	UINT bw;
	BYTE work[FF_MAX_SS];

	// Set up the file system.
	res = f_mkfs("", 0, work, sizeof work);
	if(res)
	{
		xil_printf("Failed to create file system on disk.");
		return XST_FAILURE;
	}

	usleep(1000000);
	Xil_DCacheInvalidate();

	// Mount the drive.
	f_mount(&fs, "", 0);

	// Create a file.
	res = f_open(&fil, "hello.txt", FA_CREATE_NEW | FA_WRITE);
	if(res)
	{
		xil_printf("Failed to create a file for writing.");
		return XST_FAILURE;
	}

	// WRite a message.
	f_write(&fil, "Hello, World!\r\n", 15, &bw);
	if (bw != 15)
	{
		xil_printf("Failed to write to the file.");
		return XST_FAILURE;
	}

	// Close the file and unmount the drive.
	f_close(&fil);
	f_mount(0, "", 0);

	xil_printf("Successfully wrote to a file on disk.");
	return XST_SUCCESS;
}

/****************************************************************************/
/**
* This function initializes a XDMA PCIe IP built as a root complex
*
*
* @param	XdmaPciePtr is a pointer to an instance of XDmaPcie data
*		structure represents a root complex IP.
* @param 	DeviceId is XDMA PCIe IP unique ID
*
* @return
*		- XST_SUCCESS if successful.
*		- XST_FAILURE if unsuccessful.
*
* @note 	None.
*
*
******************************************************************************/
int PcieInitRootComplex(XDmaPcie *XdmaPciePtr, u16 DeviceId)
{
	int Status;
	u32 HeaderData;
	u32 InterruptMask;
	u8  BusNumber;
	u8  DeviceNumber;
	u8  FunNumber;
	u8  PortNumber;

	XDmaPcie_Config *ConfigPtr;

	ConfigPtr = XDmaPcie_LookupConfig(DeviceId);

	Status = XDmaPcie_CfgInitialize(XdmaPciePtr, ConfigPtr,
						ConfigPtr->BaseAddress);

	if (Status != XST_SUCCESS) {
		xil_printf("Failed to initialize PCIe Root Complex"
							"IP Instance\r\n");
		return XST_FAILURE;
	}

	if(!XdmaPciePtr->Config.IncludeRootComplex) {
		xil_printf("Failed to initialize...XDMA PCIE is configured"
							" as endpoint\r\n");
		return XST_FAILURE;
	}


	/* See what interrupts are currently enabled */
	XDmaPcie_GetEnabledInterrupts(XdmaPciePtr, &InterruptMask);
	xil_printf("Interrupts currently enabled are %8X\r\n", InterruptMask);

	/* Make sure all interrupts disabled. */
	XDmaPcie_DisableInterrupts(XdmaPciePtr, XDMAPCIE_IM_ENABLE_ALL_MASK);


	/* See what interrupts are currently pending */
	XDmaPcie_GetPendingInterrupts(XdmaPciePtr, &InterruptMask);
	xil_printf("Interrupts currently pending are %8X\r\n", InterruptMask);

	/* Just if there is any pending interrupt then clear it.*/
	XDmaPcie_ClearPendingInterrupts(XdmaPciePtr,
						XDMAPCIE_ID_CLEAR_ALL_MASK);

	/*
	 * Read enabled interrupts and pending interrupts
	 * to verify the previous two operations and also
	 * to test those two API functions
	 */

	XDmaPcie_GetEnabledInterrupts(XdmaPciePtr, &InterruptMask);
	xil_printf("Interrupts currently enabled are %8X\r\n", InterruptMask);

	XDmaPcie_GetPendingInterrupts(XdmaPciePtr, &InterruptMask);
	xil_printf("Interrupts currently pending are %8X\r\n", InterruptMask);

	/* Make sure link is up. */
	int Retries;
	Status = FALSE;
	/* check if the link is up or not */
        for (Retries = 0; Retries < XDMAPCIE_LINK_WAIT_MAX_RETRIES; Retries++) {
		if (XDmaPcie_IsLinkUp(XdmaPciePtr)){
			Status = TRUE;
		}
                usleep(XDMAPCIE_LINK_WAIT_USLEEP_MIN);
	}
	if (Status != TRUE ) {
		xil_printf("Link is not up\r\n");
		return XST_FAILURE;
	}

	xil_printf("Link is up\r\n");

	/*
	 * Read back requester ID.
	 */
	XDmaPcie_GetRequesterId(XdmaPciePtr, &BusNumber,
				&DeviceNumber, &FunNumber, &PortNumber);

	xil_printf("Bus Number is %02X\r\n"
			"Device Number is %02X\r\n"
				"Function Number is %02X\r\n"
					"Port Number is %02X\r\n",
			BusNumber, DeviceNumber, FunNumber, PortNumber);


	/* Set up the PCIe header of this Root Complex */
	XDmaPcie_ReadLocalConfigSpace(XdmaPciePtr,
					PCIE_CFG_CMD_STATUS_REG, &HeaderData);

	HeaderData |= (PCIE_CFG_CMD_BUSM_EN | PCIE_CFG_CMD_MEM_EN |
				PCIE_CFG_CMD_IO_EN | PCIE_CFG_CMD_PARITY |
							PCIE_CFG_CMD_SERR_EN);

	XDmaPcie_WriteLocalConfigSpace(XdmaPciePtr,
					PCIE_CFG_CMD_STATUS_REG, HeaderData);

	/*
	 * Read back local config reg.
	 * to verify the write.
	 */

	XDmaPcie_ReadLocalConfigSpace(XdmaPciePtr,
					PCIE_CFG_CMD_STATUS_REG, &HeaderData);

	xil_printf("PCIe Local Config Space is %8X at register"
					" CommandStatus\r\n", HeaderData);

	/*
	 * Set up Bus number
	 */

	HeaderData = PCIE_CFG_PRIM_SEC_BUS;

	XDmaPcie_WriteLocalConfigSpace(XdmaPciePtr,
					PCIE_CFG_PRI_SEC_BUS_REG, HeaderData);

	/*
	 * Read back local config reg.
	 * to verify the write.
	 */
	XDmaPcie_ReadLocalConfigSpace(XdmaPciePtr,
					PCIE_CFG_PRI_SEC_BUS_REG, &HeaderData);

	xil_printf("PCIe Local Config Space is %8X at register "
					"Prim Sec. Bus\r\n", HeaderData);

	/* Now it is ready to function */

	xil_printf("Root Complex IP Instance has been successfully"
							" initialized\r\n");

	return XST_SUCCESS;
}

u32 testRawWrite(u32 num, u32 size)
{
	u32 nWrite = 0;
	u32 nComplete = 0;
	u64 srcAddress = 0x20000000;
	u64 destLBA = 0;
	u32 numLBA = size >> lba_exp;
	XTime tStart, tEnd;
	u32 tElapsed_ms;

	if(size > 0x100000) { return 0; }	// Max 1MiB. TO-DO: Set via MDTS.

	// Put sequential data (byte addresses) into RAM.
	for(int i = 0; i < size; i += 4)
	{
		*(u32 *)(srcAddress + i) = i;
	}

	XTime_GetTime(&tStart);
	while(1)
	{
		// Write one block at a time when the IOCQ is below its threshold.
		if(((nWrite - nComplete) < 16) && (nWrite < num))
		{
			destLBA = 0x00000000ULL + (u64) nWrite * (u64) numLBA;
			*(u64 *)(srcAddress) = destLBA;	// Indicator for write slip.
			nvmeWrite((u8 *) srcAddress, destLBA, numLBA);
			nWrite++;
		}

		// Service IOCQ.
		nComplete += nvmeServiceIOCompletions(16);
		if(nComplete == num)
		{
			XTime_GetTime(&tEnd);
			tElapsed_ms = (tEnd - tStart) / (COUNTS_PER_SECOND / 1000);
			return tElapsed_ms;
		}

		usleep(10);
	}

	return 0;
}

u32 testRawRead(u32 num, u32 size)
{
	u32 nRead = 0;
	u32 nComplete = 0;
	u64 srcLBA = 0;
	u64 destAddress = 0x20000000;
	u32 numLBA = size >> lba_exp;
	XTime tStart, tEnd;
	u32 tElapsed_ms;

	if(size > 0x100000) { return 0; }	// Max 1MiB. TO-DO: Set via MDTS.

	// Clear the RAM buffer. (Helps with seeing if reads have actually occurred.)
	for(int i = 0; i < size; i += 4)
	{
		*(u32 *)(destAddress + i) = 0x00000000;
	}

	XTime_GetTime(&tStart);
	while(1)
	{
		// Read one block at a time when the IOCQ is below its threshold.
		if(((nRead - nComplete) < 16) && (nRead < num))
		{
			srcLBA = 0x00000000ULL + (u64) nRead * (u64) numLBA;
			nvmeRead((u8 *) destAddress, srcLBA, numLBA);
			nRead++;
		}

		// Service IOCQ.
		nComplete += nvmeServiceIOCompletions(16);
		if(nComplete == num)
		{
			XTime_GetTime(&tEnd);
			tElapsed_ms = (tEnd - tStart) / (COUNTS_PER_SECOND / 1000);
			return tElapsed_ms;
		}

		usleep(10);
	}

	return 0;
}
