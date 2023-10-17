;
; test piezo functions
; @author Tobias Weber
; @date 15-oct-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "init.asm"
;.include "sleep.asm"
.include "timer.asm"


sleep_delay = $1000
sleep_ended = $1010


;
; set a timer and wait for its interrupt
;
sleep_timer:
	pha

	lda #$00
	sta sleep_ended

	lda #$00
	sta IO_TIMER2_CTR_LOW
	lda sleep_delay
	sta IO_TIMER2_CTR_HIGH

sleep_timer_wait:
	wai
	lda sleep_ended
	;cmp #$00
	bne sleep_timer_wait_end
	bra sleep_timer_wait
sleep_timer_wait_end:

	pla
	rts



main:
	sei
	clc
	cld
	clv

	; stack pointer relative to STACK_PAGE -> 0x01ff
	ldx #$ff
	txs

	jsr ports_reset

	; piezo
	lda #PIEZO_IO_PINS_WR
	sta PIEZO_IO_PORT_WR

	; leds
	lda #LED_IO_PINS_WR
	sta LED_IO_PORT_WR

	; timer
	jsr timer_single_init

main_loop:
	lda #LED_PIN_GREEN
	sta LED_IO_PORT

	lda #$03
	sta sleep_delay

	ldx #$ff
	loop1:
		lda #$00           ; piezo pin off
		sta PIEZO_IO_PORT
		lda sleep_delay
		jsr sleep_timer
		;jsr sleep_2

		lda #PIEZO_PIN     ; piezo pin on
		sta PIEZO_IO_PORT
		lda sleep_delay
		jsr sleep_timer
		;jsr sleep_2

		dex
		bne loop1


	lda #LED_PIN_RED
	sta LED_IO_PORT

	lda #$04
	sta sleep_delay

	ldx #$ff
	loop2:
		lda #$00           ; piezo pin off
		sta PIEZO_IO_PORT
		lda sleep_delay
		jsr sleep_timer
		;jsr sleep_2

		lda #PIEZO_PIN     ; piezo pin on
		sta PIEZO_IO_PORT
		lda sleep_delay
		jsr sleep_timer
		;jsr sleep_2

		;dec sleep_delay
		dex
		bne loop2


	bra main_loop
	rts


; -----------------------------------------------------------------------------
; interrupt service routines
; -----------------------------------------------------------------------------
nmi_main:
	; force sleep end flag
	lda #$01
	sta sleep_ended
	rti



isr_main:
	pha

	clc
	lda IO_INT_FLAGS
	rol ; c == bit7, any irq
	bcc end_isr
	rol ; c == bit6, timer 1
	;bcs timer_isr
	rol ; c == bit5, timer 2
	bcs timer_isr
	bra end_isr

	timer_isr:
		lda #$01
		sta sleep_ended
		;bra end_isr

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
