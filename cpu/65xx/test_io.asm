;
; i/o test program
; @author Tobias Weber
; @date 16-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"


; -----------------------------------------------------------------------------
; variable addresses
; -----------------------------------------------------------------------------
pattern       = $1000
shift_dir     = $1001

sleep1        = $1010
sleep2        = $1011
sleep3        = $1012
sleep1_const  = $1013
sleep2_const  = $1014
sleep3_const  = $1015
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; entry point
; -----------------------------------------------------------------------------
main:
	sei
	clc
	cld
	clv

	; stack pointer relative to STACK_PAGE -> 0x01ff
	ldx #$ff
	txs

	; output to port 1
	lda #$ff
	sta IO_PORT1_WR

	; input from port 2
	;lda #$00
	;sta IO_PORT2_WR

	; set delay constants
	lda #$01
	sta sleep3_const
	lda #$ff
	sta sleep2_const
	lda #$ff
	sta sleep1_const

	lda #$00
	sta shift_dir
	lda #$01
	sta pattern

	main_loop:
		; latch pattern to port 1
		lda pattern
		sta IO_PORT1

		lda shift_dir
		;cmp #$00
		bne shift_right

		shift_left:
			clc
			lda pattern
			rol

			cmp #$80
			bne cont

			lda #$01
			sta shift_dir
			lda #$80

			jmp cont

		shift_right:
			clc
			lda pattern
			ror

			cmp #$01
			bne cont

			lda #$00
			sta shift_dir
			lda #$01

			jmp cont

		cont:

		; test input from port 2
		;lda IO_PORT2

		; save new pattern
		sta pattern

		jsr sleep
		dec sleep1_const

		jmp main_loop

	stp



;
; busy waiting using loops
;
sleep:
	lda sleep3_const
	sta sleep3
	sleep_loop_3:
		lda sleep2_const
		sta sleep2
		sleep_loop_2:
			lda sleep1_const
			sta sleep1
			sleep_loop_1:
				dec sleep1
				lda sleep1
				bne sleep_loop_1
			dec sleep2
			lda sleep2
			bne sleep_loop_2
		dec sleep3
		lda sleep3
		bne sleep_loop_3
	rts
; -----------------------------------------------------------------------------



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
