;
; test sound via piezo element
; @author Tobias Weber
; @date 23-oct-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "init.asm"
.include "timer.asm"


notes_delay_hi    = $1000
notes_delay_lo    = $1001
pause_delay_hi    = $1002
pause_delay_lo    = $1003
oscillation_count = $1004


notes_delays_hi:    .byte $03, $04, $05, $06, $05, $04, $03
notes_delays_lo:    .byte $00, $00, $00, $00, $00, $00, $00
oscillation_counts: .byte $ff, $ff, $ff, $ff, $ff, $ff, $ff

num_notes = notes_delays_lo - notes_delays_hi



play_note:
	lda #LED_PIN_GREEN
	sta LED_IO_PORT

	play_note_loop:
		lda #$00           ; piezo pin off
		sta PIEZO_IO_PORT

		ldx notes_delay_hi ; keep the pin off
		ldy notes_delay_lo
		jsr timer_single_sleep

		lda #PIEZO_PIN     ; piezo pin on
		sta PIEZO_IO_PORT

		ldx notes_delay_hi ; keep the pin on
		ldy notes_delay_lo
		jsr timer_single_sleep

		dec oscillation_count
		bne play_note_loop

	lda #LED_PIN_RED
	sta LED_IO_PORT
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

	; set up piezo
	lda #PIEZO_IO_PINS_WR
	sta PIEZO_IO_PORT_WR

	; set up leds
	lda #LED_IO_PINS_WR
	sta LED_IO_PORT_WR

	; set up timer
	jsr timer_single_init

	lda #$00
	sta pause_delay_hi
	lda #$ff
	sta pause_delay_lo

	; play notes array
	ldx #$00
	notes_loop:
		phx

		lda notes_delays_hi, x
		sta notes_delay_hi

		lda notes_delays_lo, x
		sta notes_delay_lo

		lda oscillation_counts, x
		sta oscillation_count

		jsr play_note

		ldx pause_delay_hi 
		ldy pause_delay_lo
		jsr timer_single_sleep

		plx
		inx
		cpx #num_notes
		bne notes_loop

	stp
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
