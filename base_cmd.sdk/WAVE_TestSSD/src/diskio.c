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
#include "nvme.h"

/*-----------------------------------------------------------------------*/
/* Get Drive Status                                                      */
/*-----------------------------------------------------------------------*/

DSTATUS disk_status (
	BYTE pdrv		/* Physical drive nmuber to identify the drive */
)
{
	int nvmeStatus = nvmeGetStatus();
	if(nvmeStatus == NVME_OK) { return 0; }

	return STA_NOINIT;
}



/*-----------------------------------------------------------------------*/
/* Inidialize a Drive                                                    */
/*-----------------------------------------------------------------------*/

DSTATUS disk_initialize (
	BYTE pdrv				/* Physical drive nmuber to identify the drive */
)
{
	int nvmeStatus = nvmeGetStatus();
	if(nvmeStatus == NVME_NOINIT)
	{
		nvmeStatus = nvmeInit();
	}
	if(nvmeStatus == NVME_OK) { return 0; }

	return STA_NOINIT;
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
	int nvmeRWStatus = nvmeRead(buff, (u64) sector, count);
	if(nvmeRWStatus != NVME_RW_OK) { return RES_ERROR; }

	// No slip allowed for testing.
	while(nvmeGetIOSlip() > 1)
	{
		nvmeServiceIOCompletions(16);
	}

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
	int nvmeRWStatus = nvmeWrite(buff, (u64) sector, count);
	if(nvmeRWStatus != NVME_RW_OK) { return RES_ERROR; }

	// No slip allowed for testing.
	while(nvmeGetIOSlip() > 1)
	{
		nvmeServiceIOCompletions(16);
	}

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
	QWORD numLBA;
	WORD sizeLBA;

	switch(cmd)
	{
	case CTRL_SYNC:
		// TO-DO: Implement IO queue flush and possibly also NVMe flush command.
		return RES_OK;
	case GET_SECTOR_COUNT:
		numLBA = nvmeGetLBACount();
		if((numLBA == 0) || (numLBA > 0x100000000))
		{
			return RES_ERROR;
		}
		else
		{
			*(LBA_t *) buff = *(LBA_t*) numLBA;
			return RES_OK;
		}
	case GET_SECTOR_SIZE:
		sizeLBA = nvmeGetLBASize();
		if((sizeLBA != 512) && (sizeLBA != 4096))
		{
			return RES_ERROR;
		}
		else
		{
			*(WORD *) buff = sizeLBA;
			return RES_OK;
		}
	case GET_BLOCK_SIZE:
		// Unknown block size, return 1.
		*(DWORD *) buff = 1;
		return RES_OK;
	}

	return RES_PARERR;
}

