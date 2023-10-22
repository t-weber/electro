;
; test piezo functions
; @author Tobias Weber
; @date 15-oct-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "init.asm"
.include "timer.asm"


sleep_delay = $1000


;
; set a timer and wait for its interrupt
;
sleep_timer:
	phx
	phy

	ldx sleep_delay
	ldy #$00
	jsr timer_single_sleep

	ply
	plx
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
