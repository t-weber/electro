;
; keypad test
; @author Tobias Weber
; @date 23-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "keypad.asm"
.include "lcd.asm"
.include "string.asm"
.include "sleep.asm"


; input number as string
num = $1000


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

	jsr ports_reset
	jsr sleep_init
	jsr lcd_init
	jsr keys_init
	jsr keypad_init

	jsr lcd_clear
	jsr lcd_return

	main_end:
		wai
		bra main_end
	rts
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; interrupt service routines
; -----------------------------------------------------------------------------
nmi_main:
	rti



isr_main:
	pha
	phx
	phy
	sei

	clc
	lda IO_INT_FLAGS
	rol ; c == bit7, any irq
	bcc end_isr_tmp
	rol ; c == bit6, timer 1
	bcs end_isr_tmp
	rol ; c == bit5, timer 2
	bcs end_isr_tmp
	rol ; c == bit4, cb1 -> keys irq
	bcs keys_isr
	rol ; c == bit5, cb2 -> keypad irq
	bcs keypad_isr
	bra end_isr_tmp

	; individual key pressed
	keys_isr:
		; read data pins
		lda KEYS_IO_PORT
		and #KEYS_IO_MASK
		rol  ; move the keys out
		rol  ; of the keypad range
		rol
		rol
		and #%11110000
		pha  ; save input key

		; convert input number to char
		lda #(.lobyte(num))
		sta REG_DST_LO
		lda #(.hibyte(num))
		sta REG_DST_HI
		pla       ; restore input key
		ldy #$00
		jsr u8tostr_hex

		; print char
		lda #(.lobyte(num))
		sta REG_SRC_LO
		lda #(.hibyte(num))
		sta REG_SRC_HI
		jsr lcd_print

		bra end_isr

	end_isr_tmp:
		bra end_isr

	; key on keypad pressed
	keypad_isr:
		jsr keypad_disable_irq

		lda #KEYPAD_INIT_DELAY
		jsr sleep_1

		ldx #$01  ; currently polled key
		cb2_isr_input_loop:
			; create a falling clock edge
			lda #KEYPAD_IO_PIN_CLK    ; clk = 1
			sta KEYPAD_IO_PORT
			lda #KEYPAD_PULSE_DELAY
			jsr sleep
			lda #$00                  ; clk = 0
			sta KEYPAD_IO_PORT
			lda #KEYPAD_PULSE_DELAY
			jsr sleep

			; read data pin
			lda KEYPAD_IO_PORT
			and #KEYPAD_IO_PIN_DAT
			cmp #KEYPAD_IO_PIN_DAT    ; active low
			beq cb2_isr_no_key_pressed

			; convert input number to char
			lda #(.lobyte(num))
			sta REG_DST_LO
			lda #(.hibyte(num))
			sta REG_DST_HI
			txa       ; get input number
			cmp #$10  ; treat key '16' as '0'
			bne cb2_isr_input_not_0
				lda #$00
			cb2_isr_input_not_0:
			ldy #$00
			jsr u8tostr_hex

			; print char
			lda #(.lobyte(num))
			sta REG_SRC_LO
			lda #(.hibyte(num))
			sta REG_SRC_HI
			jsr lcd_print
			bra cb2_isr_input_loop_end  ; no multi-key presses

			cb2_isr_no_key_pressed:
			inx       ; next key
			cpx #$11  ; last key?
			beq cb2_isr_input_loop_end
			bra cb2_isr_input_loop
		cb2_isr_input_loop_end:

		lda IO_INT_FLAGS
		ora #IO_INT_FLAG_CB2  ; clear ind. keypad irq flag
		sta IO_INT_FLAGS

		jsr keypad_enable_irq

		bra end_isr

	end_isr:
	cli

	ply
	plx
	pla
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
