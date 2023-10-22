;
; serial keypad and parallel keys functions
; @author Tobias Weber
; @date 14-oct-2023
; @license see 'LICENSE' file
;

.ifndef __KEYPAD_DEFS__
__KEYPAD_DEFS__ = 1

.include "defs.inc"



;
; initialise parallel interface for the keys
;
keys_init:
	sei

	; input from keys
	lda #KEYS_IO_PINS_WR
	sta KEYS_IO_PORT_WR

	; enable keys (cb1) interrupt
	lda IO_INT_ENABLE
	ora #(IO_INT_FLAG_IRQSET | IO_INT_FLAG_CB1)
	sta IO_INT_ENABLE

	; generate interrupt on pos. edge
	lda IO_PORTS_CTRL
	ora #IO_PORTS_CB1_POSEDGE
	sta IO_PORTS_CTRL

	cli
	lda KEYS_IO_PORT      ; clear keys irq flag

	rts



;
; initialise serial interface for the keypad
;
keypad_init:
	sei

	; input from keypad
	lda #KEYPAD_IO_PINS_WR
	sta KEYPAD_IO_PORT_WR

	; enable keypad (cb2)
	lda IO_INT_ENABLE
	ora #(IO_INT_FLAG_IRQSET | IO_INT_FLAG_CB2)
	sta IO_INT_ENABLE

	; generate interrupt on pos. edge
	lda IO_PORTS_CTRL
	ora #IO_PORTS_CB2_POSEDGE_IND
	sta IO_PORTS_CTRL

	cli
	; clear irq
	lda IO_INT_FLAGS
	ora #IO_INT_FLAG_CB2  ; clear ind. keypad irq flag
	sta IO_INT_FLAGS

	rts



;
; enable keypad irq
;
keypad_enable_irq:
	pha

	; enable keypad (cb2)
	lda IO_INT_ENABLE
	ora #(IO_INT_FLAG_IRQSET | IO_INT_FLAG_CB2)
	sta IO_INT_ENABLE

	pla
	rts



;
; disable keypad irq
;
keypad_disable_irq:
	pha

	; disable keypad (cb2)
	lda #IO_INT_FLAG_CB2
	sta IO_INT_ENABLE

	pla
	rts


.endif
