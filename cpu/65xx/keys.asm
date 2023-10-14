;
; tact key functions
; @author Tobias Weber
; @date 8-oct-2023
; @license see 'LICENSE' file
;

.ifndef __KEYS_DEFS__
__KEYS_DEFS__ = 1

.include "defs.inc"


;
; initialise parallel interface for the keys
;
keys_init:
	sei

	; input from keys
	lda #KEYS_IO_PINS_WR
	sta KEYS_IO_PORT_WR

	; disable all interrupts
	lda #%01111111
	sta IO_INT_ENABLE

	; only enable cb1 interrupts
	lda #(IO_INT_FLAG_IRQSET | IO_INT_FLAG_CB1)
	sta IO_INT_ENABLE

	; generate interrupt on pos. edge
	lda #IO_PORTS_CB1_POSEDGE
	sta IO_PORTS_CTRL

	cli

	; clear irq
	lda KEYS_IO_PORT

	rts


.endif
