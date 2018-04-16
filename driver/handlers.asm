;; handlers.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; These are the handlers for int13h subfunctions. Each function gets a
;; separate handler.

AH0h_HandlerForDiskControllerReset:
        MOV     AH, 0h
	    JMP	    int13_success_return

AH1h_HandlerForReadDiskStatus:
        MOV     AH, [RAMVARS.last_ah]
        JMP     int13_success_return

AH2h_HandlerForReadDiskSectors:
        POP     BX                     ; restore BX which was lost in the jump
        PUSH    BX

        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI

        MOV     DI, BX                 ; ES:DI = destination

        ; DS is already RAMVARS segment

        MOV     BYTE [DS:RAMVARS.sec_num], 0

        MOV     BH, 0
        MOV     BL, AL                 ; BX = number of sectors to transfer

.next_sector:
        CALL    call_pi

        MOV     SI, 0400h
        CLD                            ; clear direction flag
        MOV     CX, 0100h              ; copy 512 bytes
        REP     MOVSW

        INC     BYTE [DS:RAMVARS.sec_num]

        DEC     BX
        JNZ     .next_sector

        POP     DI
        POP     SI
        POP     CX
        POP     BX

        MOV     AH, 0h
        JMP     int13_success_return

AH3h_HandlerForWriteDiskSectors:
        POP     BX                     ; restore BX which was lost in the jump
        PUSH    BX

        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DI

        MOV     DI, BX                 ; ES:DI = destination

        ; DS is already RAMVARS segment

        MOV     BYTE [DS:RAMVARS.sec_num], 0

        MOV     BH, 0
        MOV     BL, AL                 ; BX = number of sectors to transfer

.next_sector:
        MOV     SI, 0400h

        PUSH    DS                     ; swap ES:DI and DS:SI
        PUSH    ES
        POP     DS
        POP     ES
        XCHG    SI, DI

        CLD                            ; clear direction flag
        MOV     CX, 0100h              ; copy 512 bytes
        REP     MOVSW

        PUSH    DS                     ; swap ES:DI and DS:SI
        PUSH    ES
        POP     DS
        POP     ES
        XCHG    SI, DI

        CALL    call_pi

        INC     BYTE [DS:RAMVARS.sec_num]

        DEC     BX
        JNZ     .next_sector

        POP     DI
        POP     SI
        POP     CX
        POP     BX

        MOV     AH, 0h
        JMP     int13_success_return

AH4h_HandlerForVerifyDiskSectors:
        MOV     AH, 0h
        JMP     int13_success_return

AH8h_HandlerForReadDiskDriveParameters:
        CALL    call_pi
        MOV     AX, [DS:RAMVARS.ret_ax]
        MOV     BX, [DS:RAMVARS.ret_bx]
        MOV     CX, [DS:RAMVARS.ret_cx]
        MOV     DX, [DS:RAMVARS.ret_dx]

        PUSH    DS                        ; ES:DI = dpt
        POP     ES
        MOV     DI, RAMVARS.dpt

        JMP     int13_success_return_bx

AH9h_HandlerForInitializeDriveParameters:
        MOV     AH, 0h
        JMP     int13_success_return

AHCh_HandlerForSeek:
        MOV     AH, 0h
        JMP     int13_success_return

AH10h_HandlerForCheckDriveReady:
        MOV     AH, 0h
        JMP     int13_success_return

AH11h_HandlerForRecalibrate:
        MOV     AH, 0h
        JMP     int13_success_return

AH15h_HandlerForReadDiskDriveSize:
        CALL    call_pi

        MOV     AX, [DS:RAMVARS.ret_ax]
        MOV     CX, [DS:RAMVARS.ret_cx]
        MOV     DX, [DS:RAMVARS.ret_dx]

        JMP     int13_success_return_zero

AH23h_HandlerForSetControllerFeatures:
        MOV     AH, 1h
        JMP     int13_error_return

AH24h_HandlerForSetMultipleBlocks:
        MOV     AH, 1h
        JMP     int13_error_return

AH25h_HandlerForGetDriveInformation:
        MOV     AH, 1h
        JMP     int13_error_return

call_pi:
        ; Make a call to the raspberry pi:
        ;   1) Store the registers in RAMVARS
        ;   2) Write something to mbox_right
        ;   3) Wait for mbox_left to change
        ;   4) return success or fail in AH

        MOV     [DS:RAMVARS.ax], AX
        MOV     [DS:RAMVARS.bx], BX
        MOV     [DS:RAMVARS.cx], CX
        MOV     [DS:RAMVARS.dx], DX

        MOV     AH, [DS:RAMVARS.mbox_left]

        INC     BYTE [DS:RAMVARS.mbox_right]

.wait_for_pi:
        CMP     AH, [DS:RAMVARS.mbox_left]
        JE      .wait_for_pi

        MOV     AH, [DS:RAMVARS.ax],

        RET



