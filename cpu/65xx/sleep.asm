;
; sleep functions
; @author Tobias Weber
; @date 24-sep-2023
; @license see 'LICENSE' file
;

.ifndef __SLEEP_DEFS__
__SLEEP_DEFS__ = 1

.include "defs.inc"

.ifdef USE_TIMER_BASED_WAITING
	.include "timer.asm"
.endif



;
; initialise timer-based waiting
;
sleep_init:
.ifdef USE_TIMER_BASED_WAITING
	jsr timer_single_init
.endif
	rts



;
; busy waiting using one loop
; a = sleep time
;
sleep_1:
.ifdef USE_TIMER_BASED_WAITING
	phx
	phy

	ldx #$00
	tay
	jsr timer_single_sleep

	ply
	plx

.else
	sleep1_loop_a:
		dec
		bne sleep1_loop_a

.endif

	rts


;
; busy waiting using two loops
; a = sleep time
;
sleep_2:
sleep:
.ifdef USE_TIMER_BASED_WAITING
	phx
	phy

	tax
	ldy #$ff
	jsr timer_single_sleep

	ply
	plx

.else
	phx

	sleep2_loop_a:
		ldx #$ff
		sleep2_loop_x:
			dex
			bne sleep2_loop_x
		dec
		bne sleep2_loop_a

	plx
.endif

	rts


;
; busy waiting using three loops
; a = sleep time
;
sleep_3:
	phx
	phy

	sleep3_loop_a:
.ifdef USE_TIMER_BASED_WAITING
		ldx #$ff
		ldy #$ff
		jsr timer_single_sleep

.else
		ldx #$ff
		sleep3_loop_x:
			ldy #$ff
			sleep3_loop_y:
				dey
				bne sleep3_loop_y
			dex
			bne sleep3_loop_x

.endif
		dec
		bne sleep3_loop_a

	ply
	plx
	rts


.endif
