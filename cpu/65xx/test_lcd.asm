;
; lcd test
; @author Tobias Weber
; @date 24-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "lcd.asm"


str: .asciiz "Test 123"


; -----------------------------------------------------------------------------
; entry point
; -----------------------------------------------------------------------------
main:
	sei
	clc
	cld
	clv

	; stack pointer relative to STACK_PAGE -> 0x01ff
	ldx #$ff
	txs

	jsr lcd_init

	; ---------------------------------------------------------------------
	; write text
nop
nop
nop
nop
nop
nop
nop
nop
nop
	lda #(.lobyte(str))
	sta REG_SRC_LO
	lda #(.hibyte(str))
	sta REG_SRC_HI
	jsr lcd_print
nop
nop
nop
nop
nop
nop
nop
nop
nop
	; ---------------------------------------------------------------------

	stp
	rts
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; interrupt service routines
; -----------------------------------------------------------------------------
nmi_main:
	pha
	phx
	phy

	ldx #'X'
	jsr lcd_send_byte

	ply
	plx
	pla
	rti



isr_main:
	rti
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; table with entry point function pointers
; -----------------------------------------------------------------------------
.segment "JMPTAB"
	.addr nmi_main
	.addr main
	.addr isr_main
; -----------------------------------------------------------------------------
