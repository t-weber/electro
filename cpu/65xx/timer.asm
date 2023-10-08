;
; timer functions
; @author Tobias Weber
; @date 8-oct-2023
; @license see 'LICENSE' file
;

.ifndef __TIMER_DEFS__
__TIMER_DEFS__ = 1

.include "defs.inc"


;
; initialise keypad parallel interface
; x = timer value
;
timer_init:
	sei

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
	txa
	;lda #$ff
	sta IO_TIMER1_LATCH_LOW
	sta IO_TIMER1_CTR_LOW
	;lda #$ff
	sta IO_TIMER1_LATCH_HIGH
	sta IO_TIMER1_CTR_HIGH

	lda #$00
	sta counter

	cli

	; clear irq
	lda IO_TIMER1_CTR_LOW

	rts


.endif
