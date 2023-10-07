;
; sleep functions
; @author Tobias Weber
; @date 24-sep-2023
; @license see 'LICENSE' file
;

.ifndef __SLEEP_DEFS__
__SLEEP_DEFS__ = 1

.include "defs.inc"


;
; busy waiting using one loop
; a = sleep time
;
sleep_1:
	sleep1_loop_1:
		dec
		bne sleep1_loop_1

	rts


;
; busy waiting using two loops
; a = sleep time
;
sleep_2:
sleep:
	phx

	sleep2_loop_1:
		ldx #$ff
		sleep2_loop_2:
			dex
			bne sleep2_loop_2
		dec
		bne sleep2_loop_1

	plx
	rts


.endif
