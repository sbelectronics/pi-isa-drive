;; ramvar.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; RAM variables. When used as a DOS TSR, we grab a kilobyte starting at 7K
;; under the assumption that the TSR was set to reserve 8K. TSR mode is just
;; for development, not for real use.
;;
;; When run as a BIOS extension, we decrement the available memory count in the
;; BDA by one page, then install a "signature" so we can find it later. Stole
;; this idea from xt-ide.

RAMVARS_SIGNATURE equ  "Sb"

steal_ram_bios:
        ;; The idea comes from XT-IDE. Steal some RAM from the BIOS. Store a
        ;; signature so we can find it again.
	PUSH    DS
	PUSH    AX
	XOR     AX, AX
        MOV     DS, AX          ; DS=0, seg of BDA
	MOV	AX, [DS:413h]   ; number of 1K pages is at 0:413
%ifdef WRITE_SUPPORT
        SUB     AX, 5           ; steal 5KB
%else
	DEC	AX              ; steal 1KB
%endif
	MOV	[DS:413h], AX   ; store the reduced number of pages

	SHL     AX, 1 		; AX holds segment of RAMVARS
	SHL     AX, 1
	SHL     AX, 1
	SHL     AX, 1
	SHL     AX, 1
	SHL     AX, 1
        MOV	DS, AX
	MOV     WORD [DS:RAMVARS.signature], RAMVARS_SIGNATURE

	POP     AX
	POP     DS
        RET

find_ramvars_bios:
        ;; Stolen from XT-IDE
        ;; Returns
        ;;     DS - RamVars Segment
        PUSH    AX
        PUSH    DI
        XOR     AX, AX
        MOV     DS, AX                         ; DS=0, seg of BDA
        MOV     DI, [DS:413h]                  ; Load available base memory size in kB
        SHL     DI, 1
        SHL     DI, 1
        SHL     DI, 1
        SHL     DI, 1
        SHL     DI, 1
        SHL     DI, 1

.LoopStolenKBs:
        mov             ds, di                                  ; EBDA segment to DS
        add             di, BYTE 64                             ; DI to next stolen kB
        cmp             WORD [RAMVARS.signature], RAMVARS_SIGNATURE
        jne             SHORT .LoopStolenKBs    ; Loop until sign found (always found eventually)
        POP     DI
        POP     AX
        ret

steal_ram_dos:
        ;; For developing in DOS. This is a no-op.
        RET

find_ramvars_dos:
        ;; For developing in DOS. Just assume that RAMVARS are at CS plus
        ;; 7K. The TSR will have reserved 12K, so that leaves us 5K of ramvars
        ;; Returns:
        ;;     DS - RamVars Segment
        PUSH    AX
        MOV     AX, CS
        ADD     AX, (7*1024/16)
        MOV     DS, AX
        POP     AX
        RET

struc   RAMVARS
	.signature  resb 2
        .int13_old  resb 4
        .last_ah    resb 1
%ifdef WRITE_SUPPORT
        .write_and_wait_func_addr   resb 4
        .write_and_wait_func   resb 128
        .writebuf   resb 4096
%endif
endstruc
