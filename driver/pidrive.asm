;; pidrive.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; This is the main file. It includes everything else, installs the int13h
;; handler, and returns.

cpu 8086
	
;; Uncomment the following for lots of debugging
;; %define INT13_PRINTREGS

;; Uncomment the following to turn off all text output
;; %define QUIET

;; Uncomment the following to install as a TSR, so that the driver can be loaded
;; from the DOS prompt. If not defined, will assemble as a BIOS extension.
;; %define DOS_COM_TSR

;; Uncomment to use 256 byte transfers instead of 512. This will automatically
;; be selected if assembling as a BIOS extension.
;; %define halfxfer

%ifdef DOS_COM_TSR
org 100h
find_ramvars equ find_ramvars_dos
%else
org 0h
find_ramvars  equ find_ramvars_bios
%define halfxfer
%endif

%ifdef halfxfer
secbuf_size_words equ 0x80
secbuf_offset equ RAMVARS.secbuf_small
%else
secbuf_size_words equ 0x100
secbuf_offset equ RAMVARS.secbuf_large
%endif

section .text

start:
        ;; three bytes are just enough room for a BIOS extension header...
        JMP     main
        DB      0

main:   PUSHF

%ifndef DOS_COM_TSR
        ;; Since the 2K disk is mirrored at base_address+2k, the BIOS will find the extension again. When that happens
        ;; return without doing anything.
        MOV     AX, CS
        AND     AX, 0xFF
        JZ      okay
        POPF
        RETF
okay:
%endif

        CALL    find_ramvars
        ;; The pi will want to know the size of the secbuf
        MOV     [DS:RAMVARS.secbuf_size_words], WORD secbuf_size_words
%ifndef QUIET
        CALL    banner
%endif
        CALL    install_int13_handler
%ifndef QUIET
        CALL    footer
%endif
        POPF

%ifdef DOS_COM_TSR
        MOV     ah, 31h
        MOV     al, 0
        MOV     dx, (program_size >> 4) + 1
        INT     21h
%else
        ;; return from BIOS search
        RETF
%endif

%include "romvar.asm"
%include "ramvar.asm"
%include "int13.asm"
%include "handlers.asm"

%ifndef QUIET

%include "display.asm"

banner: LEA     SI,[title]
        CALL    printstr
        LEA     SI, [banner_frame]
        CALL    printstr
        MOV     AX, [CS:shared_seg]
        CALL    print_hex_word
        CALL    newline
        RET

footer: LEA     SI, [msg_int13_1]
        CALL    printstr
        MOV     AX, [RAMVARS.int13_old]
        CALL    print_hex_word
        MOV     AL, ':'
        CALL    print_char
        MOV     AX, [RAMVARS.int13_old+2]
        CALL    print_hex_word
        CALL    newline
        LEA     SI, [msg_installed]
        CALL    printstr
        RET

;;section .data

title   DB      'Pi-Drive^'
	    DB      'by Scott M Baker, http://www.smbaker.com/^$'
banner_frame:
        DB      'frame seg: $'
msg_int13_1:
        DB      'saved int13 handler: $'
msg_installed:
        DB      'int13 handler installed^$'

%endif

program_size equ     $-start
