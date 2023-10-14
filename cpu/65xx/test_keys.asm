;
; input irq test
; @author Tobias Weber
; @date 23-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "keys.asm"



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
	lda #$00
	sta IO_PORT1

	jsr keys_init

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
	rol ; c == bit6, timer 1
	rol ; c == bit5, timer 2
	rol ; c == bit4, cb1
	bcs cb1_isr
	bra end_isr

	cb1_isr:
		; input from port 2 and output to port 1
		lda KEYS_IO_PORT
		and #KEYS_IO_MASK
		sta IO_PORT1

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
