;
; timer test program
; @author Tobias Weber
; @date 19-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "init.asm"
.include "timer.asm"


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

	jsr ports_reset

	; output to port 1
	lda #$ff
	sta IO_PORT1_WR
	lda counter
	sta IO_PORT1

	lda #$00
	sta counter

	ldx #$ff
	jsr timer_cont_init

	main_end:
		wai
		bra main_end
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
	rol ; c == bit7, any irq
	rol ; c == bit6, timer
	bcs timer_isr
	bra end_isr

	timer_isr:
		inc counter
		lda counter
		sta IO_PORT1

		; clear irq
		lda IO_TIMER1_CTR_LOW
		bra end_isr

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
