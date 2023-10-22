;
; mathematical functions
; @author Tobias Weber
; @date 22-oct-2023
; @license see 'LICENSE' file
;

.ifndef __MATH_DEFS__
__MATH_DEFS__ = 1

.include "defs.inc"


;
; multiply two unsigned integers
; a = x * y
;
umult:
	lda #$00
	cpx #$00
	beq mult_loop_end

	stx REG_IDX_1

	mult_loop:
		cpy #$00
		beq mult_loop_end

		dey
		clc
		adc REG_IDX_1
		bra mult_loop

	mult_loop_end:

	rts


.endif
