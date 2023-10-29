;
; lcd test
; @author Tobias Weber
; @date 24-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "string.asm"
.include "lcd.asm"


strconst1: .asciiz "Testing"
strconst2: .asciiz "Loop #"
strvar     = $3400  ; random memory locations
strcounter = $3500  ;
counter    = $3600  ;


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

	jsr ports_reset
	jsr sleep_init
	jsr lcd_init
	stz counter

	; ---------------------------------------------------------------------
	; write text
	main_loop:
		; -------------------------------------------------------------
		; display a string constant
		jsr lcd_clear
		jsr lcd_return

		lda #(.lobyte(strconst1))
		sta REG_SRC_LO
		lda #(.hibyte(strconst1))
		sta REG_SRC_HI
		jsr lcd_print

		lda #$ff
		jsr sleep
		; -------------------------------------------------------------

		; -------------------------------------------------------------
		; copy a string constant to a variable and display it
		lda #(.lobyte(strconst2))
		sta REG_SRC_LO
		lda #(.hibyte(strconst2))
		sta REG_SRC_HI
		lda #(.lobyte(strvar))
		sta REG_DST_LO
		lda #(.hibyte(strvar))
		sta REG_DST_HI
		jsr strcpy

		lda #LCD_LINE2
		jsr lcd_address

		lda #(.lobyte(strvar))
		sta REG_SRC_LO
		lda #(.hibyte(strvar))
		sta REG_SRC_HI
		jsr lcd_print

		lda #$ff
		jsr sleep
		; -------------------------------------------------------------

		; -------------------------------------------------------------
		; concatenate another string to the variable and display it
		lda #(.lobyte(strcounter))
		sta REG_DST_LO
		lda #(.hibyte(strcounter))
		sta REG_DST_HI
		lda counter
		ldy #$00
		jsr u8tostr_hex
		inc counter

		lda #(.lobyte(strcounter))
		sta REG_SRC_LO
		lda #(.hibyte(strcounter))
		sta REG_SRC_HI
		lda #(.lobyte(strvar))
		sta REG_DST_LO
		lda #(.hibyte(strvar))
		sta REG_DST_HI
		jsr strcat

		lda #LCD_LINE2
		jsr lcd_address

		lda #(.lobyte(strvar))
		sta REG_SRC_LO
		lda #(.hibyte(strvar))
		sta REG_SRC_HI
		jsr lcd_print

		lda #$ff
		jsr sleep
		; -------------------------------------------------------------

		lda #$ff
		jsr sleep
		bra main_loop
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
