;
; general reset and init functions
; @author Tobias Weber
; @date 14-oct-2023
; @license see 'LICENSE' file
;

.ifndef __INIT_DEFS__
__INIT_DEFS__ = 1

.include "defs.inc"


;
; disable all port interrupts
;
ports_reset:
	; disable all interrupts
	lda #%01111111
	sta IO_INT_ENABLE

	; reset io ports and aux. control
	lda #$00
	sta IO_PORTS_CTRL
	sta IO_AUX_CTRL

	rts


.endif
