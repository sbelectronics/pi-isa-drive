;; ramvar.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; RAM variables.

find_ramvars_dos:
        PUSH   AX
        MOV    AX, [CS:shared_seg]
        MOV    DS, AX
        POP    AX
        RET

find_ramvars_bios:
        PUSH   CS
        POP    DS
        RET

struc   RAMVARS

        ;; if halfxfer is defined, then we transfer 256 bytes at a time instead of 512
%ifdef  halfxfer
        .junk       resb 732
        .secbuf     resb 256
%else
        .junk       resb 476
        .secbuf     resb 512
%endif

        .int13_old  resb 4
        .last_ah    resb 1

        .ax         resb 2
        .bx         resb 2
        .cx         resb 2
        .dx         resb 2
        .sec_num    resb 2

        .ret_ax     resb 2
        .ret_bx     resb 2
        .ret_cx     resb 2
        .ret_dx     resb 2

        .dpt:
        .dpt_head_unload resb 1             ; unload=32ms, steprate=2ms
        .dpt_head_load   resb 1             ; unload=4ms, 1=no dma used
        .dpt_motor_wait  resb 1             ; 0 ticks
        .dpt_bytes_sec   resb 1             ; 512 bytes per sector
        .dpt_sec_trk     resb 1             ; 9 sectors per track
        .dpt_gap         resb 1
        .dpt_data_len    resb 1
        .dpt_gap_len_f   resb 1
        .dpt_fill_byte   resb 1
        .dpt_head_sett   resb 1
        .dpt_motor_st    resb 1

        .mbox_left  resb 1
        .mbox_right resb 1                  ; must be at 3FFh
endstruc
