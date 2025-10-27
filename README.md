README PENDING TO COMPLETE

For now it works without home folder even if you create it. No loop devices (i'll have to stop the framework).

*********************
#### !!WARNING!!
WHILE ALPINE IS RUNNING / THE IMAGE IS MOUNTED, DO NOT CONNECT YOUR KINDLE TO THE COMPUTER WITHOUT USBNETWORK ENABLED! The image resides in /mnt/us, and that is your usb mass storage location. When Alpine and the computer write on the userstore partition (partition 4) at the same time, it will be destroyed, and you need to fix that partition to get your Kindle working again. It might even be possible to brick the Kindle!!! Kual has an option to show the USBNetwork status, so check that beforehand if you plan on doing SSH while Alpine runs.
*********************
