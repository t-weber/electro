;
; serial keypad functions
; @author Tobias Weber
; @date 14-oct-2023
; @license see 'LICENSE' file
;

.ifndef __KEYPAD_DEFS__
__KEYPAD_DEFS__ = 1

.include "defs.inc"


;
; initialise serial interface for the keypad
; and parallel interface for the keys
;
keypad_init:
	sei

	; input from keys
	lda #KEYPAD_IO_PINS_WR
	sta KEYPAD_IO_PORT_WR

	; disable all interrupts
	lda #%01111111
	sta IO_INT_ENABLE

	; enable keypad (cb2) and keys (cb1) interrupts
	lda #(IO_INT_FLAG_IRQSET | IO_INT_FLAG_CB2 | IO_INT_FLAG_CB1)
	sta IO_INT_ENABLE

	; generate interrupt on pos. edge
	;lda #IO_PORTS_CB2_POSEDGE
	lda #(IO_PORTS_CB2_POSEDGE_IND | IO_PORTS_CB1_POSEDGE)
	sta IO_PORTS_CTRL

	cli
	; clear irqs
	;lda #IO_INT_FLAG_CB2  ; clear ind. keypad irq flag
	;sta IO_INT_FLAGS
	;lda KEYPAD_IO_PORT   ; clear std. keypad irq flag
	lda KEYS_IO_PORT      ; clear keys irq flag

	rts


.endif
