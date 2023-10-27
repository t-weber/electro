;
; test sound via piezo element
; @author Tobias Weber
; @date 23-oct-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "init.asm"
.include "timer.asm"
.include "string.asm"
.include "lcd.asm"


notes_delay_hi = $1000
notes_delay_lo = $1001
pause_delay_hi = $1002
pause_delay_lo = $1003
base_length    = $1004
notes_length   = $1005

msg_note       = $1010
msg_note_hi    = $1020
msg_note_lo    = $1030
msg            = $1040

strnote: .asciiz "Note "
strcolon: .asciiz ": "


;
; delay times for 1 MHz clock:
; string(round(Int, 1 / freq / 2 * 1e6), base = 16)
;
; melody: https://en.wikipedia.org/wiki/Symphony_No._9_(Beethoven)#IV._Finale
; tuning: https://en.wikipedia.org/wiki/Equal_temperament
; TODO: correct length for note delays
;
notes_delays_hi: .byte $03,$03,$03, $03,$03,$03,$04, $04,$04,$03, $03,$04,$04, $03,$03,$03
                 .byte $03,$03,$03,$04, $04,$04,$03, $04,$04,$04, $04,$03,$04, $04,$03,$03,$03,$04
                 .byte $04,$03,$03,$03,$04, $04,$04,$06,$03, $03,$03,$03,$03, $03,$03,$03,$04
                 .byte $04,$04,$03, $04,$04,$04
notes_delays_lo: .byte $be,$88,$25, $25,$88,$be,$33, $b7,$33,$be, $be,$33,$33, $be,$88,$25
                 .byte $25,$88,$be,$33, $b7,$33,$be, $33,$b7,$b7, $33,$be,$b7, $33,$be,$88,$be,$b7
                 .byte $33,$be,$88,$be,$33, $b7,$33,$4b,$be, $be,$be,$88,$25, $25,$88,$be,$33
                 .byte $b7,$33,$be, $33,$b7,$b7
notes_lengths:   .byte $04,$02,$02, $02,$02,$02,$02, $04,$02,$02, $03,$01,$04, $04,$02,$02
                 .byte $02,$02,$02,$02, $04,$02,$02, $03,$01,$04, $04,$02,$02, $02,$01,$01,$02,$02
                 .byte $02,$01,$01,$02,$02, $02,$02,$02,$02, $02,$02,$02,$02, $02,$02,$02,$02
                 .byte $04,$02,$02, $03,$01,$04

num_notes    = notes_delays_lo - notes_delays_hi
base_lengths = $7f



play_note:
;	lda #LED_PIN_GREEN
;	sta LED_IO_PORT

	play_note_loop_outer:
		lda #base_lengths
		sta base_length

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

			dec base_length
			bne play_note_loop

		dec notes_length
		bne play_note_loop_outer

;	lda #LED_PIN_RED
;	sta LED_IO_PORT
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

	; set up lcd
	jsr lcd_init

	lda #$00
	sta pause_delay_hi
	lda #$ff
	sta pause_delay_lo

	; play notes array
	ldx #$00                         ; current note index
	notes_loop:
		phx                      ; save current note index

		; --------------------------------------------------------------------------------
		; load note frequencies (delays) and lengths
		; --------------------------------------------------------------------------------
		lda notes_delays_hi, x
		sta notes_delay_hi

		lda notes_delays_lo, x
		sta notes_delay_lo

		lda notes_lengths, x
		sta notes_length
		; --------------------------------------------------------------------------------

		; --------------------------------------------------------------------------------
		; status message
		; --------------------------------------------------------------------------------
		jsr lcd_clear
		jsr lcd_return

		; convert note index to string msg_note
		lda #(.lobyte(msg_note))
		sta REG_DST_LO
		lda #(.hibyte(msg_note))
		sta REG_DST_HI
		pla                      ; get note index into a...
		pha                      ; ...and save it again
		ldy #$00
		jsr u8tostr_hex

		; convert note delay to string msg_note_hi
		lda #(.lobyte(msg_note_hi))
		sta REG_DST_LO
		lda #(.hibyte(msg_note_hi))
		sta REG_DST_HI
		lda notes_delay_hi
		ldy #$00
		jsr u8tostr_hex

		; convert note delay to string msg_note_lo
		lda #(.lobyte(msg_note_lo))
		sta REG_DST_LO
		lda #(.hibyte(msg_note_lo))
		sta REG_DST_HI
		lda notes_delay_lo
		ldy #$00
		jsr u8tostr_hex

		; strcpy strnote -> msg
		lda #(.lobyte(strnote))
		sta REG_SRC_LO
		lda #(.hibyte(strnote))
		sta REG_SRC_HI
		lda #(.lobyte(msg))
		sta REG_DST_LO
		lda #(.hibyte(msg))
		sta REG_DST_HI
		jsr strcpy

		; strcat msg_note -> msg
		lda #(.lobyte(msg_note))
		sta REG_SRC_LO
		lda #(.hibyte(msg_note))
		sta REG_SRC_HI
		lda #(.lobyte(msg))
		sta REG_DST_LO
		lda #(.hibyte(msg))
		sta REG_DST_HI
		jsr strcat

		; strcat strcolon -> msg
		lda #(.lobyte(strcolon))
		sta REG_SRC_LO
		lda #(.hibyte(strcolon))
		sta REG_SRC_HI
		lda #(.lobyte(msg))
		sta REG_DST_LO
		lda #(.hibyte(msg))
		sta REG_DST_HI
		jsr strcat

		; strcat msg_note_hi -> msg
		lda #(.lobyte(msg_note_hi))
		sta REG_SRC_LO
		lda #(.hibyte(msg_note_hi))
		sta REG_SRC_HI
		lda #(.lobyte(msg))
		sta REG_DST_LO
		lda #(.hibyte(msg))
		sta REG_DST_HI
		jsr strcat

		; strcat msg_note_lo -> msg
		lda #(.lobyte(msg_note_lo))
		sta REG_SRC_LO
		lda #(.hibyte(msg_note_lo))
		sta REG_SRC_HI
		lda #(.lobyte(msg))
		sta REG_DST_LO
		lda #(.hibyte(msg))
		sta REG_DST_HI
		jsr strcat

		; print message
		lda #(.lobyte(msg))
		sta REG_SRC_LO
		lda #(.hibyte(msg))
		sta REG_SRC_HI
		jsr lcd_print
		; --------------------------------------------------------------------------------

		jsr play_note

		ldx pause_delay_hi       ;
		ldy pause_delay_lo       ; delay after playing note
		jsr timer_single_sleep   ;

		plx                      ; restore current note index
		inx                      ; next note
		cpx #num_notes           ; finished?
		bne notes_loop_tmp
		bra notes_loop_end

	notes_loop_tmp:                  ;
		jmp notes_loop           ; long jump hack
	notes_loop_end:                  ;

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
