;; romvar.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; ROM variables (aka constants)

                ALIGN   2

romvar_sig      DB      "RVAR",0

;; Drive number. This is the drive the int13 handler will intercept.
;;   0 = first floppy
;;   1 = second floppy
;;   80h = first hdd
;;   81h = second hdd

drive_num       DB      0h        ; first floppy

;; Hardware information. Where to find the page register and page frame. This
;; needs to match the dipswitch settings on the PCB.

default_shared_seg EQU    0E000h
shared_seg	    DW      default_shared_seg



