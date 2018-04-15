;; int13.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; Int13 handler. Install the int13 handler and save the old one to a spot in
;; ramvars. When an int13 occurs, check to see if its out drive. If so, call
;; the appropriate handler. If it's not our drive then call the old handler.

install_int13_handler:
        ;; assumes RAMVARS segment is in DS
        PUSH    SI
        MOV     SI, int13_handler
        MOV     [RAMVARS.int13_old], SI
        MOV     [RAMVARS.int13_old+2], CS
        POP     SI
        JMP     exchange_int13_handler

exchange_int13_handler:
        ;; assumes RAMVARS segment is in DS
        PUSH    ES
        PUSH    SI
        XOR     SI, SI
        MOV     ES, SI
        MOV     SI, [RAMVARS.int13_old]
        CLI
        XCHG    SI, [ES:13h*4]
        MOV     [RAMVARS.int13_old], SI
        MOV     SI, [RAMVARS.int13_old+2]
        XCHG    SI, [ES:13h*4+2]
        STI
        MOV     [RAMVARS.int13_old+2], SI
        POP     SI
        POP     ES
        RET

int13_handler:
%ifdef  INT13_PRINTREGS
        CALL    printregs_enter
%endif
        PUSH    DS
        CALL    find_ramvars
        CMP     DL, [CS:drive_num]
        JE      .ourdrive
        CALL    exchange_int13_handler
        INT     13h
        PUSHF                          ; make sure carry flag is preserved
        CALL    exchange_int13_handler
        POPF
        POP     DS
%ifdef  INT13_PRINTREGS
        CALL    printregs_exit
%endif
        JMP     iret_fuss_with_carry_flag
.ourdrive:
        PUSH    BX
        XOR     BX, BX
        MOV     BL, AH
        SHL     BX, 1
        CMP     AH, 25h
        JA      unsupported_function
        JMP     [cs:bx+int13_jumptable]

unsupported_function:
        MOV     AH, 01h
        JMP     int13_error_return

iret_fuss_with_carry_flag:
        JC .carryset
        PUSH    BP
        MOV     BP, SP
        AND     BYTE [BP+6], 0FEh
        POP     BP
        IRET
.carryset:
        PUSH    BP
        MOV     BP, SP
        OR      BYTE [BP+6], 1
        POP     BP
        IRET

iret_fuss_with_carry_flag_old:
        ;; Since IRET will restore the carry flag, tamper with the stack to
        ;; set the carry flag to what we want.
        JC .carryset
        ADD SP, 4                      ; skip over CS and IP
        POPF
        CLC
        PUSHF
        SUB SP, 4
        IRET
.carryset:
        ADD SP, 4                      ; skip over CS and IP
        POPF
        STC
        PUSHF
        SUB SP, 4
        IRET

int13_error_return:
        MOV     [RAMVARS.last_ah], ah

        POP     BX
        POP     DS
        STC                       ; set carry
%ifdef  INT13_PRINTREGS
        CALL    printregs_exit
%endif
        JMP     iret_fuss_with_carry_flag

int13_success_return:
        ;; For all functions except 8h and 15h. Error code is in AH.
        MOV     [RAMVARS.last_ah], ah

        POP     BX
        POP     DS
        CLC                       ; clear carry
%ifdef  INT13_PRINTREGS
        CALL    printregs_exit
%endif
        JMP     iret_fuss_with_carry_flag

int13_success_return_zero:
        ;; For function 15h, which returns AH != 0, even on success
        MOV     [RAMVARS.last_ah], BYTE 0

        POP     BX
        POP     DS
        CLC                       ; clear carry
%ifdef  INT13_PRINTREGS
        CALL    printregs_exit
%endif
        JMP     iret_fuss_with_carry_flag

int13_success_return_bx:
        ;; For function 8h, and anyone else who returns stuff in BX
        MOV     [RAMVARS.last_ah], ah

        POP     DS                ; get BX off the stack; we'll overwrite DX in a moment
        POP     DS
        CLC                       ; clear carry
%ifdef  INT13_PRINTREGS
        CALL    printregs_exit
%endif
        JMP     iret_fuss_with_carry_flag

        ALIGN   2

int13_jumptable:
        dw      AH0h_HandlerForDiskControllerReset                      ; 00h, Disk Controller Reset (All)
        dw      AH1h_HandlerForReadDiskStatus                           ; 01h, Read Disk Status (All)
        dw      AH2h_HandlerForReadDiskSectors                          ; 02h, Read Disk Sectors (All)
        dw      AH3h_HandlerForWriteDiskSectors                         ; 03h, Write Disk Sectors (All)
        dw      AH4h_HandlerForVerifyDiskSectors                        ; 04h, Verify Disk Sectors (All)
        dw      unsupported_function                                                     ; 05h, Format Disk Track (XT, AT, EISA)
        dw      unsupported_function                                                     ; 06h, Format Disk Track with Bad Sectors (XT)
        dw      unsupported_function                                                     ; 07h, Format Multiple Cylinders (XT)
        dw      AH8h_HandlerForReadDiskDriveParameters                                  ; 08h, Read Disk Drive Parameters (All)
        dw      AH9h_HandlerForInitializeDriveParameters                                ; 09h, Initialize Drive Parameters (All)
        dw      unsupported_function                                                     ; 0Ah, Read Disk Sectors with ECC (XT, AT, EISA)
        dw      unsupported_function                                                     ; 0Bh, Write Disk Sectors with ECC (XT, AT, EISA)
        dw      AHCh_HandlerForSeek                                                     ; 0Ch, Seek (All)
        dw      AH9h_HandlerForInitializeDriveParameters                                ; 0Dh, Alternate Disk Reset (All)
        dw      unsupported_function                                                     ; 0Eh, Read Sector Buffer (XT, PS/1), ESDI Undocumented Diagnostic (PS/2)
        dw      unsupported_function                                                     ; 0Fh, Write Sector Buffer (XT, PS/1), ESDI Undocumented Diagnostic (PS/2)
        dw      AH10h_HandlerForCheckDriveReady                                         ; 10h, Check Drive Ready (All)
        dw      AH11h_HandlerForRecalibrate                                             ; 11h, Recalibrate (All)
        dw      unsupported_function                                                     ; 12h, Controller RAM Diagnostic (XT)
        dw      unsupported_function                                                     ; 13h, Drive Diagnostic (XT)
        dw      unsupported_function                                                     ; 14h, Controller Internal Diagnostic (All)
        dw      AH15h_HandlerForReadDiskDriveSize                                       ; 15h, Read Disk Drive Size (AT+)
        dw      unsupported_function                                                     ; 16h,
        dw      unsupported_function                                                     ; 17h,
        dw      unsupported_function                                                     ; 18h,
        dw      unsupported_function                                                     ; 19h, Park Heads (PS/2)
        dw      unsupported_function                                                     ; 1Ah, Format ESDI Drive (PS/2)
        dw      unsupported_function                                                     ; 1Bh, Get ESDI Manufacturing Header (PS/2)
        dw      unsupported_function                                                     ; 1Ch, ESDI Special Functions (PS/2)
        dw      unsupported_function                                                     ; 1Dh,
        dw      unsupported_function                                                     ; 1Eh,
        dw      unsupported_function                                                     ; 1Fh,
        dw      unsupported_function                                                     ; 20h,
        dw      unsupported_function                                                     ; 21h, Read Disk Sectors, Multiple Blocks (PS/1)
        dw      unsupported_function                                                     ; 22h, Write Disk Sectors, Multiple Blocks (PS/1)
        dw      AH23h_HandlerForSetControllerFeatures                                   ; 23h, Set Controller Features Register (PS/1)
        dw      AH24h_HandlerForSetMultipleBlocks                                       ; 24h, Set Multiple Blocks (PS/1)
        dw      AH25h_HandlerForGetDriveInformation                                     ; 25h, Get Drive Information (PS/1)


debug1  DB      'enter AX: $'
debug2  DB      'success exit AX: $'
debug3  DB      'success2 exit AX: $'
debug4  DB      'error exit AX: $'
debug5  DB      ' CX: $'
debug6  DB      ' DX: $'

