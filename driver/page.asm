;; page.asm
;; Scott M Baker, http://www.smbaker.com/
;;
;; Page flipping functions. page_enable() must be called before pages can
;; be flipped.

set_page0:
	;; set page 1 register to value in AL

	PUSH	DX
	MOV	DX, [CS:page_reg]
	OUT	DX, AL
	POP	DX
	RET

set_page1:
	;; set page 1 register to value in AL

	PUSH	DX
	MOV	DX, [CS:page_reg]
        INC     DX
	OUT	DX, AL
	POP	DX
	RET

set_page2:
	;; set page 2 register to value in AL

	PUSH	DX
	MOV	DX, [CS:page_reg]
        INC     DX
        INC     DX
	OUT	DX, AL
	POP	DX
	RET

set_page3:
	;; set page 3 register to value in AL

	PUSH	DX
	MOV	DX, [CS:page_reg]
        INC     DX
        INC     DX
        INC     DX
	OUT	DX, AL
	POP	DX
	RET

enable_page:
	;; enable page register
	
	PUSH    AX
	PUSH	DX
	MOV	DX, [CS:page_enable]
	MOV     AL, 1
	OUT	DX, AL
	POP     DX
	POP	AX
	RET
