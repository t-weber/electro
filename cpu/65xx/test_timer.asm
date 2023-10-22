;
; timer test program
; @author Tobias Weber
; @date 19-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "init.asm"
.include "timer.asm"
.include "sleep.asm"
.include "string.asm"
.include "lcd.asm"



; -----------------------------------------------------------------------------
; variables
; -----------------------------------------------------------------------------
NUM_COUNTER_BYTES = 4
counter           = $1000  ; counter having length NUM_COUNTER_BYTES
strcounter        = $1010  ; counter string
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

	.repeat NUM_COUNTER_BYTES, n
		stz counter + n
	.endrep

	jsr ports_reset
	jsr sleep_init
	jsr lcd_init

	ldx #$27  ; ca. 10 ms
	ldy #$10  ;
	jsr timer_cont_init

	main_loop:
		;wai

		jsr lcd_clear
		jsr lcd_return

		; convert counter to string
		lda #(.lobyte(strcounter))
		sta REG_DST_LO
		lda #(.hibyte(strcounter))
		sta REG_DST_HI
		lda #(.lobyte(counter))
		sta REG_SRC_LO
		lda #(.hibyte(counter))
		sta REG_SRC_HI
		ldy #$00
		ldx #NUM_COUNTER_BYTES
		jsr uNtostr_hex

		; print counter
		lda #(.lobyte(strcounter))
		sta REG_SRC_LO
		lda #(.hibyte(strcounter))
		sta REG_SRC_HI
		jsr lcd_print

		lda #$04
		jsr sleep_3

		bra main_loop
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
	bcc end_isr
	rol ; c == bit6, timer
	bcs timer_isr
	bra end_isr

	timer_isr:
		.repeat NUM_COUNTER_BYTES, n
			inc counter + n
			bne timer_isr_counter_end
		.endrep

	timer_isr_counter_end:
		; clear irq
		lda IO_TIMER1_CTR_LOW

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
