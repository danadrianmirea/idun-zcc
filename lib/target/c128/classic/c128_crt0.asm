;       Commodore 128 (Z80 mode) CRT0 stub
;
;       Stefano Bodrato - 22/08/2001
;
;	$Id: c128_crt0.asm,v 1.28 2016/07/15 21:03:25 dom Exp $
;


                MODULE  c128_crt0

;--------
; Include zcc_opt.def to find out some info
;--------
        defc    crt0 = 1
        INCLUDE "zcc_opt.def"

; Only the ANSI terminal is available
;	defc NEED_ansiterminal = 1  <-- specified elsewhere

;--------
; Some scope definitions
;--------

        EXTERN    _main           ;main() is always external to crt0 code

        PUBLIC    cleanup         ;jp'd to by exit()
        PUBLIC    l_dcal          ;jp(hl)

        defc    CONSOLE_COLUMNS = 40
        defc    CONSOLE_ROWS = 25

        IF      !DEFINED_CRT_ORG_CODE
                defc    CRT_ORG_CODE  = $3000	
        ENDIF

	defc	TAR__no_ansifont = 1
	defc	TAR__clib_exit_stack_size = 32
	defc	TAR__register_sp = -1
	defc __CPU_CLOCK = 2000000
	INCLUDE	"crt/classic/crt_rules.inc"
        org     CRT_ORG_CODE


start:

	; Write anything to the proper preconfiguration register to switch to BANK 1
	; Our code runs in RAM01 exclusively, thus leaving the Idun environment in
	; RAM00 undisturbed.
	defb $8D	; STA ..
	defw $FF02
;ENDIF

	; Prepare the "springboard" for the z80
	defb $A9	; LDA ..
	defb 195	; ..opcode for JP (z80)
	defb $8D	; STA ..
	defw 65518
	
	defb $A9	; LDA ..
	defb z80start&$FF
	defb $8D	; STA ..
	defw 65519
	
	defb $A9	; LDA ..
	defb z80start/256
	defb $8D	; STA ..
	defw 65520
	; Returning to the 8502 is via code that is setup
	; by the `zload` command, at $1100 in RAM00

	defb $4C	; JMP
	defw 65488

z80start:
	di
	
	; Set VIC-IIe to use RAM01/$2000 for its text display
	ld	bc,$dd00
	in	a,(c)
	or	a,$03
	out	(c),a
	ld	bc,$d018
	ld	a,$87
	out	(c),a	; 40 columns text at $2000
	ld  bc,$d506
	in	a,(c)
	or	a,$40
	out	(c),a	; use RAM01 for VIC block
	
	xor	a		; black
	ld	bc,$d020
	out	(c),a	;border
	inc	c
	out	(c),a	;& background

	ld hl,$FBFF
	ld sp,$FBFF
    ld      (__restore_sp_onexit+1),hl
    INCLUDE "crt/classic/crt_init_sp.asm"
    INCLUDE "crt/classic/crt_init_atexit.asm"
    call	crt0_init_bss
    ld      (exitsp),sp

; Optional definition for auto MALLOC init
; it assumes we have free space between the end of 
; the compiled program and the stack pointer
	IF DEFINED_USING_amalloc
		INCLUDE "crt/classic/crt_init_amalloc.asm"
	ENDIF

        call    _main

cleanup:
    call    crt0_exit

__restore_sp_onexit:
        ld  sp,0
        jp  $FFE0

l_dcal:
        jp  (hl)
	
; If we were given an address for the BSS then use it
IF DEFINED_CRT_ORG_BSS
	defc	__crt_org_bss = CRT_ORG_BSS
ENDIF

	INCLUDE "crt/classic/crt_runtime_selection.asm"

	INCLUDE "crt/classic/crt_section.asm"

	SECTION	code_crt_init
	ld	hl,$2000
	ld	(base_graphics),hl

	PUBLIC	_vdcDispMem
	defc	_vdcDispMem = base_graphics
