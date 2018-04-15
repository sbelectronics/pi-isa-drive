;; romvar.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; ROM variables (aka constants)

                ALIGN   2

romvar_sig      DB      "FLASHBIO_ROM_VARS",0

;; Hardware information. Where to find the page register and page frame. This
;; needs to match the dipswitch settings on the PCB.

default_page_reg   EQU    260h
default_frame_seg  EQU    0E000h

WRITE_PROTECT      EQU    0
WRITE_IGNORE       EQU    1
WRITE_WRITE        EQU    2

page_reg     	DW	default_page_reg
page_enable     DW      default_page_reg + 4
page_frame_seg	DW      default_frame_seg

;; Drive number. This is the drive the int13 handler will intercept.
;;   0 = first floppy
;;   1 = second floppy
;;   80h = first hdd
;;   81h = second hdd

drive_num       DB      0h        ; first floppy

;; Floppy drive geometry is below. This is setup for a 360K floppy, under the
;; assumption that fits nicely in a single 512K FLASH chip. You can make it
;; bigger, for example a 720K or 1.44MB floppy, by using multiple FLASH chips.

drive_type      DB      1         ; floppy, cannot detect change (func 15h)
floppy_type     DB      1h        ; 360K floppy (func 08h)
num_cyl         DB      40
num_head        DB      2
num_sec         DB      9

write_mode      DB      WRITE_WRITE

;; Disk parameter table. I'm unsure how important all of this is.

dpt:
dpt_head_unload DB      0             ; unload=32ms, steprate=2ms
dpt_head_load   DB      1             ; unload=4ms, 1=no dma used
dpt_motor_wait  DB      0             ; 0 ticks
dpt_bytes_sec   DB      2             ; 512 bytes per sector
dpt_sec_trk     DB      9             ; 9 sectors per track
dpt_gap         DB      0
dpt_data_len    DB      0FFh
dpt_gap_len_f   DB      0
dpt_fill_byte   DB      0F6h
dpt_head_sett   DB      0
dpt_motor_st    DB      0

