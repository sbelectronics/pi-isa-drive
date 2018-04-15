;; util.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; Various utility functions.

retdos:
        ;; return to DOS, when run as a COM file.
        MOV     ah, 04Ch
        MOV     al, 0
        int     21h

tsr:
        ;; terminate and stay resident, when run as a COM file.
        mov     ah, 31h
        mov     al, 0
        mov     dx, 300h ; reserve 12k
        int     21h

ret_bios_search:
        ;; return from BIOS extension scan, when compiled as a BIOS extension
        RETF
