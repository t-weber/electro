;
; keypad functions
; @author Tobias Weber
; @date 8-oct-2023
; @license see 'LICENSE' file
;

.ifndef __KEYPAD_DEFS__
__KEYPAD_DEFS__ = 1

.include "defs.inc"


;
; initialise keypad parallel interface
;
keypad_init:
	sei

	; input from keypad
	lda #KEYPAD_IO_PINS_WR
	sta KEYPAD_IO_PORT_WR

	; disable all interrupts
	lda #%01111111
	sta IO_INT_ENABLE

	; only enable cb1 interrupts
	lda #%10010000
	sta IO_INT_ENABLE

	; generate interrupt on pos. edge
	lda #%00010000
	sta IO_PORTS_CTRL

	cli

	; clear irq
	lda KEYPAD_IO_PORT

	rts


.endif
