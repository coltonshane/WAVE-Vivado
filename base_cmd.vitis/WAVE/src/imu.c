/*
IMU Methods

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
#include "imu.h"
#include "xspips.h"

// Private Pre-Processor Definitions -----------------------------------------------------------------------------------

#define SPI1_DEVICE_ID XPAR_XSPIPS_1_DEVICE_ID

// BMI160 registers.
#define BMI160_CHIPID 0x00			 // Who-Am-I
#define BMI160_CMD 0x7E              // command interface for power control
#define BMI160_GYR_RANGE 0x43        // gyro range
#define BMI160_GYR_CONF 0x42         // gyro configuration
#define BMI160_ACC_RANGE 0x41        // accel range
#define BMI160_ACC_CONF 0x40         // accel configuration
#define BMI160_GYR_RATE_X_LSB 0x0C   // gyro X axis LSB
#define BMI160_TEMPERATURE_LSB 0x20  // chip temperature LSB
#define BMI160_INT_EN_0 0x51         // interrupt enable register
#define BMI160_INT_OUT_CTRL 0x53     // interrupt output type register
#define BMI160_INT_MAP_1 0x56        // interrupt mapping register

#define BMI160_WR_REG 0x00           // MSB 0 to write
#define BMI160_RD_REG 0x80           // MSB 1 to read
#define BMI160_ADDR_MASK 0x7F		 // Bits 6:0 are the register address

// Private Type Definitions --------------------------------------------------------------------------------------------

// Private Function Prototypes -----------------------------------------------------------------------------------------

u8 imuRegRead(XSpiPs * spiDevice, u8 addr);
void imuRegWrite(XSpiPs * spiDevice, u8 addr, u8 val);

// Public Global Variables ---------------------------------------------------------------------------------------------

// Private Global Variables --------------------------------------------------------------------------------------------

XSpiPs Spi1;
XSpiPs_Config *spi1Config;

// Interrupt Handlers --------------------------------------------------------------------------------------------------

// Public Function Definitions -----------------------------------------------------------------------------------------

void imuInit(void)
{
	// Set up SPI0 for CMV12000 serial control.
	spi1Config = XSpiPs_LookupConfig(SPI1_DEVICE_ID);
	XSpiPs_CfgInitialize(&Spi1, spi1Config, spi1Config->BaseAddress);
	XSpiPs_SetOptions(&Spi1, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION);
	XSpiPs_SetClkPrescaler(&Spi1, XSPIPS_CLK_PRESCALE_64);
	XSpiPs_SetSlaveSelect(&Spi1, 0x0F);

	u8 test;
	test = imuRegRead(&Spi1, BMI160_CHIPID);
	if(test == 0xD1)
	{
		test = 0x00;
	}
}

// Private Function Definitions ----------------------------------------------------------------------------------------

u8 imuRegRead(XSpiPs * spiDevice, u8 addr)
{
	u8 txBuffer[] = {0x00, 0x00};
	u8 rxBuffer[] = {0x00, 0x00};
	u8 val = 0x00;

	txBuffer[0] = BMI160_RD_REG | (addr & BMI160_ADDR_MASK);
	XSpiPs_SetSlaveSelect(spiDevice, 0x00);
	usleep(1);
	XSpiPs_PolledTransfer(spiDevice, txBuffer, rxBuffer, 2);
	usleep(1);
	XSpiPs_SetSlaveSelect(spiDevice, 0x0F);
	val = rxBuffer[1];

	return val;
}

void imuRegWrite(XSpiPs * spiDevice, u8 addr, u8 val)
{
	u8 txBuffer[] = {0x00, 0x00};
	u8 rxBuffer[] = {0x00, 0x00};

	txBuffer[0] = BMI160_WR_REG | (addr & BMI160_ADDR_MASK);
	txBuffer[1] = val;
	XSpiPs_SetSlaveSelect(spiDevice, 0x00);
	usleep(1);
	XSpiPs_PolledTransfer(spiDevice, txBuffer, rxBuffer, 2);
	usleep(1);
	XSpiPs_SetSlaveSelect(spiDevice, 0x0F);
}
