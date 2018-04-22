#!/bin/bash
set -x -e
sudo mkdir -p /mnt/msdos
sudo losetup /dev/loop0 images/workdisk.img
sudo mount -t msdos /dev/loop0 /mnt/msdos
