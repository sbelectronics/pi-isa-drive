;; wrtflash.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; Code for writing to flash.
;;
;;  * * * UNTESTED * * *

;; write_flash
;;    DS:SI = source data (DS must be RAMVARS segment)
;;    AL    = page number
;;    DI    = dest offset within page
;;    CX    = byte count
;; destroys:
;;    AX, BX, CX, DX, SI, ES, DI

write_flash:
        MOV     BX, [CS:page_frame_seg]
        MOV     ES, BX                 ; ES = page frame dest segment

        MOV     DX, [CS:page_reg]
        INC     DX                     ; DX = port number of page 1 reg

        ADD     DI, 4000h              ; bank 1 is at 4000

.NEXT_BYTE:
        MOV     AH, AL                 ; save AL into AH
        AND     AL, 0E0h               ; mask off the lower 5 bits

        INC     AL
        OUT     DX, AL
        MOV     [ES:5555h], byte 0AAh  ; bank1+5555 = AA

        DEC     AL
        OUT     DX, AL
        MOV     [ES:6AAAh], byte 055h  ; bank1+2AAA = 55

        INC     AL
        OUT     DX, AL
        MOV     [ES:5555h], byte 0A0h  ; bank1+5555 = A0

        MOV     AL, AH                 ; restore AL from AH
        OUT     DX, AL                 ; set desired page number

        ;; XXX MOVSB                         ; move byte in [DS:SI] to [ES:DI]

        MOV     BL, [DS:SI]            ; get byte to write
        CALL    FAR [DS:RAMVARS.write_and_wait_func_addr]  ; far call to RAMVARS.waitfunc

        INC     SI                     ; increment src, dest offsets
        INC     DI

        DEC     CX
        JNZ     .NEXT_BYTE

        RET

;; erase_flash_sector
;;    DS    = RAMVARS segment
;;    AL    = page number
;;    DI    = dest offset within page (lower 12 bits ignored)
;; destroys:
;;    AX, BX, DX, ES

erase_flash_sector:
        MOV     BX, [CS:page_frame_seg]
        MOV     ES, BX                 ; ES = page frame dest segment

        MOV     DX, [CS:page_reg]
        INC     DX                     ; DX = port number of page 1 reg

        ADD     DI, 4000h              ; bank 1 is at 4000

        MOV     AH, AL                 ; save AL into AH
        AND     AL, 0E0h               ; mask off the lower 5 bits

        INC     AL
        OUT     DX, AL
        MOV     [ES:5555h], byte 0AAh  ; bank1+5555 = AA

        DEC     AL
        OUT     DX, AL
        MOV     [ES:6AAAh], byte 055h  ; bank1+2AAA = 55

        INC     AL
        OUT     DX, AL
        MOV     [ES:5555h], byte 080h  ; bank1+5555 = 80

        OUT     DX, AL
        MOV     [ES:5555h], byte 0AAh  ; bank1+5555 = AA

        DEC     AL
        OUT     DX, AL
        MOV     [ES:6AAAh], byte 055h  ; bank1+2AAA = 55

        MOV     AL, AH                 ; restore AL from AH
        OUT     DX, AL                 ; set desired page number

        ;;MOV     [ES:DI], byte 30h      ; bank1+secaddr = 30

        MOV     BL, 30h
        CALL    FAR [DS:RAMVARS.write_and_wait_func_addr]  ; far call to RAMVARS.waitfunc

        SUB     DI, 4000h              ; restore DI

        RET

;; write_and_wait_on_flash
;;     ES:DI = destination address
;;     BL = byte to write
;; destroys:
;;     BH

write_and_wait_on_flash:
        MOV     [ES:DI], BL
        ;; Wait for the write operation to complete. The chip will toggle the
        ;; sixth bit during reads while the operation is in progress. If we
        ;; read an address twice and the sixth bit is the same, then we know
        ;; we are complete.
wait_on_flash:
        MOV     BL, [ES:4000h]
.WAIT:
        MOV     BH, [ES:4000h]
        XCHG    BH, BL
        CMP     BH, BL
        JNE     .WAIT
        RETF

;; We can't execute write_and_wait_on_flash from Flash, because Flash will be
;; toggling bit D6 on all reads whenever an operation is in progress. So,
;; copy the func to RAMVARS, and then we can far call it in ram.

copy_waitfunc:
        PUSH    CX
        PUSH    SI
        PUSH    DI
        PUSH    DS
        PUSH    ES

        PUSH    DS
        POP     ES                     ; ES = ramvars segment
        MOV     DI, RAMVARS.write_and_wait_func

        PUSH    CS
        POP     DS                     ; DS = code segment
        MOV     SI, write_and_wait_on_flash

        MOV     CX, 32
        REP     MOVSW                  ; copy 64 bytes

        ;; now store the address of the function, so we can far call it

        MOV     [ES:RAMVARS.write_and_wait_func_addr], WORD RAMVARS.write_and_wait_func
        MOV     [ES:RAMVARS.write_and_wait_func_addr+2], ES

        POP     ES
        POP     DS
        POP     DI
        POP     SI
        POP     CX

        RET



erase_wait_msg db 'Erase Start^$'
erase_done_msg db 'Erase Complete^$'
write_wait_msg db 'Write Start^$'
write_done_msg db 'Write Done^$'


