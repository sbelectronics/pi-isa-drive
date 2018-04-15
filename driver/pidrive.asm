;; flashbio.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; This is the main file. It includes everything else, installs the int13h
;; handler, and returns.

        org 100h

cpu 8086
	
section .text

;; Uncomment the following for lots of debugging
;; %define INT13_PRINTREGS

;; Uncomment the following to install as a TSR, for testing of the COM file
;; from the dos prompt.
;; %define DOS_COM_TSR

;; Uncomment the following to enable write to flash. It will use up an
;; additional 4K of lower memory.
%define WRITE_SUPPORT

%ifdef DOS_COM_TSR
find_ramvars equ find_ramvars_dos
steal_ram    equ steal_ram_dos
finished     equ tsr
%else
find_ramvars  equ find_ramvars_bios
steal_ram     equ steal_ram_bios
finished      equ ret_bios_search
%endif

start:
        JMP     main

%include "romvar.asm"

main:   PUSHF
        CALL    steal_ram
        CALL    find_ramvars
        CALL    banner
        MOV     AL, 0
        CALL    set_page0              ; make sure page0=0 before enabling
        CALL    enable_page
        CALL    install_int13_handler

%ifdef WRITE_SUPPORT
        CALL    copy_waitfunc
%endif

        LEA     SI, [msg_int13_1]
        CALL    printstr
        MOV     AX, [RAMVARS.int13_old]
        CALL    print_hex_word
        MOV     AL, ':'
        CALL    print_char
        MOV     AX, [RAMVARS.int13_old+2]
        CALL    print_hex_word
        CALL    newline

        ;;CALL    test_chs_to_block

        LEA     SI, [msg_installed]
        CALL    printstr

        ;; point banks 1-3 to something other than the bios extension, to
        ;; prevent bios from detecting the extension again in another bank.
        MOV     AL, 1
        CALL    set_page1
        CALL    set_page2
        CALL    set_page3

        POPF
        JMP     finished

test_chs_to_block:
        ;; An early test case for checking the C/H/S -> blk math.
        ;; Math is hard.
        MOV     CH, 1   ; cyl
        MOV     CL, 3   ; sector
        MOV     DH, 1   ; head
        CALL    chs_to_blk
        MOV     AX, DX
        CALL    print_hex_word       ; print block
        CALL    newline
        CALL    blk_to_page
        CALL    print_hex_word       ; print page
        CALL    newline
        MOV     AX, SI
        CALL    print_hex_word       ; print byte offset
        CALL    newline
        RET

banner: LEA     SI,[title]
        CALL    printstr
        LEA     SI, [banner_pagereg]
        CALL    printstr
        MOV     AX, [CS:page_reg]
        CALL    print_hex_word
        LEA     SI, [banner_frame]
        CALL    printstr
        MOV     AX, [CS:page_frame_seg]
        CALL    print_hex_word
        LEA     SI, [banner_ramvars]
        CALL    printstr
        MOV     AX, DS
        CALL    print_hex_word
        CALL    newline
        RET

%include "ramvar.asm"
%include "display.asm"
%include "page.asm"
%include "util.asm"

%ifdef WRITE_SUPPORT
%include "wrtflash.asm"
%endif

%include "int13.asm"
%include "handlers.asm"

section .data

title   DB      'FlashBios^'
	DB      'by Scott M Baker, http://www.smbaker.com/^$'
banner_pagereg:
        DB      'page register: $'
banner_frame:
        DB      ' frame seg: $'
banner_ramvars:
        DB      ' ramvars seg: $'
msg_int13_1:
        DB      'saved int13 handler: $'
msg_installed:
        DB      'int13 handler installed^$'
