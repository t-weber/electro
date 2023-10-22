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
; initialise continuous timer
; x = timer high byte value
; y = timer low byte value
;
timer_cont_init:
	sei

	; only enable timer 1 interrupts
	lda IO_INT_ENABLE
	ora #(IO_INT_FLAG_IRQSET | IO_INT_FLAG_TIMER1)
	sta IO_INT_ENABLE

	; set continuous timer interrupts
	lda IO_AUX_CTRL
	and #%00111111
	ora #IO_AUX_TIMER1_CONT
	sta IO_AUX_CTRL

	; timer delay
	tya
	sta IO_TIMER1_LATCH_LOW
	sta IO_TIMER1_CTR_LOW
	txa
	sta IO_TIMER1_LATCH_HIGH
	sta IO_TIMER1_CTR_HIGH

	cli

	; clear irq
	lda IO_TIMER1_CTR_LOW

	rts



;
; initialise single timer
;
timer_single_init:
	sei

	; only enable timer 2 interrupts
	lda IO_INT_ENABLE
	ora #(IO_INT_FLAG_IRQSET | IO_INT_FLAG_TIMER2)
	sta IO_INT_ENABLE

	; set single timer interrupt
	lda IO_AUX_CTRL
	and #%11011111
	sta IO_AUX_CTRL

	cli
	rts



;
; set a single timer and wait for its interrupt
; x = timer high byte value
; y = timer low byte value
; ca. 1 ms -> x = #$03, y = #$e8
;
timer_single_sleep:
	sei
	pha

	; start timer
	tya
	sta IO_TIMER2_CTR_LOW
	txa
	sta IO_TIMER2_CTR_HIGH

	timer_single_sleep_wait:
		wai  ; wait for timer end interrupt

		; in-line interrupt service routine
		lda IO_INT_FLAGS
		rol ; c == bit7, any irq
		rol ; c == bit6, timer 1
		rol ; c == bit5, timer 2
		bcs timer_single_sleep_wait_end
		bra timer_single_sleep_wait

	timer_single_sleep_wait_end:
		; clear interrupt flag
		lda IO_TIMER2_CTR_LOW

	pla
	cli
	rts



.endif
