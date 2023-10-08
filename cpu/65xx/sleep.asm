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
	sleep1_loop_a:
		dec
		bne sleep1_loop_a

	rts


;
; busy waiting using two loops
; a = sleep time
;
sleep_2:
sleep:
	phx

	sleep2_loop_a:
		ldx #$ff
		sleep2_loop_x:
			dex
			bne sleep2_loop_x
		dec
		bne sleep2_loop_a

	plx
	rts


;
; busy waiting using three loops
; a = sleep time
;
sleep_3:
	phx
	phy

	sleep3_loop_a:
		ldx #$ff
		sleep3_loop_x:
			ldy #$ff
			sleep3_loop_y:
				dey
				bne sleep3_loop_y
			dex
			bne sleep3_loop_x
		dec
		bne sleep3_loop_a

	ply
	plx
	rts


.endif
