#!/bin/bash
set -x -e
sudo umount /mnt/msdos
sudo losetup -d /dev/loop0
