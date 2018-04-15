;; handlers.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; These are the handlers for int13h subfunctions. Each function gets a
;; separate handler.

AH0h_HandlerForDiskControllerReset:
        MOV     AH, 0h
	JMP	int13_success_return

AH1h_HandlerForReadDiskStatus:
        ;;MOV     AH, 0h
        MOV     AH, [RAMVARS.last_ah]
        JMP     int13_success_return

AH2h_HandlerForReadDiskSectors:
        POP     BX                     ; restore BX which was lost in the jump
        PUSH    BX

        PUSH    AX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    DS

        MOV     DI, BX                 ; ES:DI = destination

        PUSH    AX
        CALL    chs_to_blk             ; DX = block number, AX/BX/CX=wrecked
        POP     AX

        MOV     BX, [CS:page_frame_seg]
        MOV     DS, BX                 ; DS = page frame source segment

        MOV     BH, 0
        MOV     BL, AL                 ; BX = number of sectors to transfer

.next_sector:
        CALL    blk_to_page            ; AX = page, SI = offset, CX=wrecked
        INC     AL                     ; inc page number because page0 = BIOS ext
        CALL    set_page1

        ADD     SI, 0x4000             ; DS:SI = source; use window 1

        CLD                            ; clear direction flag
        MOV     CX, 0100h              ; copy 512 bytes
        REP     MOVSW

        INC     DX                     ; increment block count
        DEC     BX                     ; decrement blocks remaining
        JNZ     .next_sector

        POP     DS
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     AX

        MOV     AH, 0h
        JMP     int13_success_return

AH3h_HandlerForWriteDiskSectors:
        MOV     AH, [cs:write_mode]
        CMP     AH, WRITE_PROTECT
        JNE     .NOT_WRITE_PROTECT
        MOV     AH, 3h                 ; write protected
        MOV     AL, 0                  ; zero sectors written
        JMP     int13_error_return
.NOT_WRITE_PROTECT:
        CMP     AH, WRITE_IGNORE
        JNE     .NOT_WRITE_IGNORE
        MOV     AH, 0h                 ; silently ignore the write
        JMP     int13_success_return
.NOT_WRITE_IGNORE:
%ifndef WRITE_SUPPORT
        ;; write support is not compiled in, so return write protected error
        MOV     AH, 3h                 ; write protected
        MOV     AL, 0                  ; zero sectors written
        JMP     int13_error_return
%else
        ;; this must be WRITE_WRITE
        ;;   * * * untested * * *
        POP     BX                     ; restore BX which was lost in the jump
        PUSH    BX

        PUSH    CX
        MOV     AH, AL                 ; number of sectors to write in AH

.NEXT_SECTOR:
        CALL    write_one_sector
        INC     CL                     ; increment sector number
        ADD     BX, 512                ; increment source pointer
        DEC     AH                     ; decrement sectors remaining
        JNZ     .NEXT_SECTOR

        POP     CX                     ; restore CX

        MOV     AH, 0h                 ; AL still has sector count
        JMP     int13_success_return

write_one_sector:
        ;; on entry
        ;;   CH = track number
        ;;   CL = sector number
        ;;   DH = head number
        ;;   DS = ramvars segment
        ;;   ES:BX = user buffer

        ;; Part 1: transfer from Flash to writebuf

        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    DS
        PUSH    ES

        PUSH    DS
        POP     ES
        MOV     DI, RAMVARS.writebuf   ; ES:DI = ram buffer

        CALL    chs_to_blk             ; DX = block number, AX/BX/CX=wrecked

        MOV     BX, [CS:page_frame_seg]
        MOV     DS, BX                 ; DS = page frame source segment

        CALL    blk_to_page            ; AX = page, SI = offset, CX=wrecked
        INC     AL                     ; inc page number because page0 = BIOS ext
        CALL    set_page1

        ADD     SI, 0x4000             ; DS:SI = source; use window 1
        AND     SI, 0xF000             ; mask off lower 12 bits to transfer whole block

        CLD                            ; clear direction flag
        MOV     CX, 0800h              ; copy 4096 bytes
        REP     MOVSW

        POP     ES
        POP     DS
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        ;; Part 2: transfer from user buffer to writebuf

        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    DS
        PUSH    ES

        MOV     SI, BX                 ; :SI = user buffer

        CALL    chs_to_blk             ; DX = block number, AX/BX/CX=wrecked
        AND     DX, 07h                ; There are 8 512B blocks per 4K sector
        MOV     CL, 9
        SHL     DX, CL                 ; DX is offset into 4K sector

        MOV     AX, ES                 ; save user segment in AX

        PUSH    DS
        POP     ES
        MOV     DI, RAMVARS.writebuf   ; ES:DI = ram buffer
        ADD     DI, DX                 ; ES:DI = destination address

        MOV     DS, AX                 ; DS:SI = user buffer

        CLD
        MOV     CX, 0100h              ; copy 512 bytes
        REP     MOVSW

        POP     ES
        POP     DS
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        ;; Part 3: transfer from writebuf to flash

        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DI
        PUSH    DS
        PUSH    ES

        CALL    chs_to_blk             ; DX = block number, AX/BX/CX=wrecked
        CALL    blk_to_page            ; AX = page, SI = offset, CX=wrecked
        INC     AL                     ; inc page number because page0 = BIOS ext

        MOV     DI, SI                 ; DI = offset within page
        AND     DI, 0xF000             ; mask off lower 12 bites

        CALL    erase_flash_sector

        MOV     SI, RAMVARS.writebuf   ; DS:SI = ram buffer
        MOV     CX, 4096               ; write the whole sector
        CALL    write_flash

        POP     ES
        POP     DS
        POP     DI
        POP     SI
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
%endif


AH4h_HandlerForVerifyDiskSectors:
        MOV     AH, 0h
        JMP     int13_success_return

AH8h_HandlerForReadDiskDriveParameters:
        MOV     AH, 0h
        MOV     AL, 0h
        MOV     BL, [CS:floppy_type]
        MOV     CH, [CS:num_cyl]
        DEC     CH                     ; number of cyls - 1
        MOV     CL, [CS:num_sec]
        MOV     DH, [CS:num_head]
        DEC     DH                     ; number of heads - 1
        MOV     DL, 1h
        PUSH    CS                     ; ES:DI = dpt
        POP     ES
        MOV     DI, [dpt]
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
        TEST    DL, DL                 ; from xt-ide: do not store sector
        JNS     .floppy                ; count if this is a floppy.

        MOV     AH, 0
        MOV     AL, [CS:num_sec]
        MOV     CH, 0
        MOV     CL, [CS:num_head]
        MUL     CX                     ; AX = sec * head
        MOV     CH, 0
        MOV     CL, [CS:num_cyl]
        MUL     CX                     ; DX:AX = cyl * sec * head

        MOV     CX, DX
        MOV     DX, AX                 ; CX:DX = num of sectors

.floppy:
        MOV     AL, 0                  ; why?
        MOV     AH, [CS:drive_type]
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

chs_to_blk:
        ;; input:
        ;;   CH = track number
        ;;   CL = sector number
        ;;   DH = head number
        ;; output:
        ;;   DX = block number
        ;; destroys:
        ;;   AX, BX, CX
        MOV     BX, CX                 ; BH=c, BL=s
        MOV     AH, 0
        MOV     AL, [CS:num_head]      ; AX = nHeads
        MOV     CH, 0
        MOV     CL, BH                 ; CX = c
        MOV     BH, DH                 ; BH = h
        MUL     CX                     ; AX = (c * nHeads), DX=0
        MOV     DL, BH
        MOV     DH, 0                  ; DX = h
        ADD     AX, DX                 ; AX = (c * nHeads + h)
        MOV     CH, 0
        MOV     CL, [CS:num_sec]
        MUL     CX                     ; AX = (c * nHeads + h) * nSectors
        MOV     BH, 0
        DEC     BL                     ; BL = (s-1)
        ADD     AX, BX                 ; AX = (c * nHeads + h) * nSectors + (s-1)
        MOV     DX, AX
        RET

blk_to_page:
        ;; input
        ;;   DX = block number
        ;; output
        ;;   AX = bank number
        ;;   SI = offset
        ;; destroys
        ;;   CX
        MOV     AX, DX
        MOV     CL, 5
        SHR     AX, CL                 ; divide by 32 sectors per bank
        MOV     CX, DX
        AND     CX, 0xFFE0             ; CX = bank * 32
        MOV     SI, DX
        SUB     SI, CX                 ; SI = block number within bank
        MOV     CL, 9
        SHL     SI, CL                  ; SI = byte offset within bank
        RET


