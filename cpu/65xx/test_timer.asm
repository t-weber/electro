;
; timer test program
; @author Tobias Weber
; @date 19-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"


; -----------------------------------------------------------------------------
; variables
; -----------------------------------------------------------------------------
counter = $1000
; -----------------------------------------------------------------------------



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

	; output to port 1
	lda #$ff
	sta IO_PORT1_WR
	lda counter
	sta IO_PORT1

	; disable all interrupts
	lda #%01111111
	sta IO_INT_ENABLE

	; only enable continuous timer interrupts
	lda #%11000000
	sta IO_INT_ENABLE

	; set continuous timer interrupts
	lda #%01000000
	sta IO_AUX_CTRL

	; timer delay
	lda #$ff
	sta IO_TIMER1_LATCH_LOW
	sta IO_TIMER1_CTR_LOW
	lda #$80
	sta IO_TIMER1_LATCH_HIGH
	sta IO_TIMER1_CTR_HIGH

	lda #$00
	sta counter

	cli

	; clear irq
	lda IO_TIMER1_CTR_LOW

	main_end:
	jmp main_end
	rts
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; interrupt service routines
; -----------------------------------------------------------------------------
nmi_main:
	rti



isr_main:
	pha

	clc
	lda IO_INT_FLAGS
	rol ; c == bit7
	rol ; c == bit6
	bcc end_isr
		; clear irq
		lda IO_TIMER1_CTR_LOW

		inc counter

		lda counter
		sta IO_PORT1
	end_isr:

	pla
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
