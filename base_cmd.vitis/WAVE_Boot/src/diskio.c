/*-----------------------------------------------------------------------*/
/* Low level disk I/O module skeleton for FatFs     (C)ChaN, 2019        */
/*-----------------------------------------------------------------------*/
/* If a working storage control module is available, it should be        */
/* attached to the FatFs via a glue function rather than modifying it.   */
/* This is an example of glue functions to attach various exsisting      */
/* storage control modules to the FatFs module with a defined API.       */
/*-----------------------------------------------------------------------*/

#include "ff.h"			/* Obtains integer types */
#include "diskio.h"		/* Declarations of disk functions */
#include "usb.h"
#include "xusb_class_storage.h"

/*-----------------------------------------------------------------------*/
/* Get Drive Status                                                      */
/*-----------------------------------------------------------------------*/

DSTATUS disk_status (
	BYTE pdrv		/* Physical drive nmuber to identify the drive */
)
{
	// Virtual drive is always OK.
	return 0;
}



/*-----------------------------------------------------------------------*/
/* Inidialize a Drive                                                    */
/*-----------------------------------------------------------------------*/

DSTATUS disk_initialize (
	BYTE pdrv				/* Physical drive nmuber to identify the drive */
)
{
	// Virtual drive is always OK.
	return 0;
}



/*-----------------------------------------------------------------------*/
/* Read Sector(s)                                                        */
/*-----------------------------------------------------------------------*/

DRESULT disk_read (
	BYTE pdrv,		/* Physical drive nmuber to identify the drive */
	BYTE *buff,		/* Data buffer to store read data */
	LBA_t sector,	/* Start sector in LBA */
	UINT count		/* Number of sectors to read */
)
{
	if((sector + count) > (VFLASH_SIZE >> 9))
	{
		return RES_ERROR;
	}

	memcpy(buff, &VirtFlash[sector << 9], count << 9);
	return RES_OK;
}



/*-----------------------------------------------------------------------*/
/* Write Sector(s)                                                       */
/*-----------------------------------------------------------------------*/

DRESULT disk_write (
	BYTE pdrv,			/* Physical drive nmuber to identify the drive */
	const BYTE *buff,	/* Data to be written */
	LBA_t sector,		/* Start sector in LBA */
	UINT count			/* Number of sectors to write */
)
{
	if((sector + count) > (VFLASH_SIZE >> 9))
	{
		return RES_ERROR;
	}

	memcpy(&VirtFlash[sector << 9], buff, count << 9);
	return RES_OK;
}


/*-----------------------------------------------------------------------*/
/* Miscellaneous Functions                                               */
/*-----------------------------------------------------------------------*/

DRESULT disk_ioctl (
	BYTE pdrv,		/* Physical drive nmuber (0..) */
	BYTE cmd,		/* Control code */
	void *buff		/* Buffer to send/receive control data */
)
{
	QWORD numLBA = VFLASH_SIZE >> 9;
	WORD sizeLBA = 0x200;

	switch(cmd)
	{
	case CTRL_SYNC:
		return RES_OK;
	case GET_SECTOR_COUNT:
		*(LBA_t *) buff = numLBA;
		return RES_OK;
	case GET_SECTOR_SIZE:
		*(WORD *) buff = sizeLBA;
		return RES_OK;
	case GET_BLOCK_SIZE:
		// Unknown block size, return 1.
		*(DWORD *) buff = 1;
		return RES_OK;
	}

	return RES_PARERR;
}

