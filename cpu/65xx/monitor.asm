;
; system monitor
; @author Tobias Weber
; @date 27-oct-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "keypad.asm"
.include "lcd.asm"
.include "string.asm"
.include "sleep.asm"


; constants
strread:  .asciiz "READ  "
strwrite: .asciiz "WRITE "
strrun:   .asciiz "RUN   "

data_len    = $08    ; number of data bytes to print
mode_read   = %00000001
mode_write  = %00000010
mode_run    = %00000100


; variables
mode        = $1000  ; program mode: read/write/run
input_key   = $1001  ; current input key

addr_lo     = $1002  ; current address
addr_hi     = $1003  ;
addr_nibble = $1004  ; current nibble for address input

mode_str    = $1010  ; mode as string
addr_str    = $1020  ; address as string
data_str    = $1030  ; data as string



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

	; initialise variables
	stz mode
	inc mode
	stz addr_lo
	stz addr_hi
	stz addr_nibble

	stz mode_str
	stz addr_str
	stz data_str

	lda #mode_read
	jsr change_mode

	main_end:
		wai
		bra main_end
	rts
; -----------------------------------------------------------------------------

;
; update the output
;
update:
	lda mode
	cmp #mode_read
	beq update_mode_read
	cmp #mode_write
	beq update_mode_write
	cmp #mode_run
	beq update_mode_run
	bra update_mode_end

	update_mode_read:
		lda #(.lobyte(data_str))
		sta REG_DST_LO
		lda #(.hibyte(data_str))
		sta REG_DST_HI
		lda addr_lo
		sta REG_SRC_LO
		lda addr_hi
		sta REG_SRC_HI
		ldx #data_len
		ldy #$00
		jsr uNtostr_hex_be
		bra update_mode_end

	update_mode_write:
		; TODO
		bra update_mode_end

	update_mode_run:
		; TODO
		;jmp (addr_lo)

	update_mode_end:

	jsr lcd_clear
	jsr lcd_return

	; print the mode string
	lda #(.lobyte(mode_str))
	sta REG_SRC_LO
	lda #(.hibyte(mode_str))
	sta REG_SRC_HI
	jsr lcd_print

	; print the address string
	lda #(.lobyte(addr_str))
	sta REG_SRC_LO
	lda #(.hibyte(addr_str))
	sta REG_SRC_HI
	jsr lcd_print

	; next line on lcd
	lda #LCD_LINE_LEN
	jsr lcd_address

	; print the data string
	lda #(.lobyte(data_str))
	sta REG_SRC_LO
	lda #(.hibyte(data_str))
	sta REG_SRC_HI
	jsr lcd_print

	rts



;
; change the program's input mode
; a = mode (key pressed)
;
change_mode:
	sta mode
	cmp #mode_read
	beq change_mode_read
	cmp #mode_write
	beq change_mode_write
	cmp #mode_run
	beq change_mode_run
	bra change_mode_end

	change_mode_read:
		; set mode string
		lda #(.lobyte(strread))
		sta REG_SRC_LO
		lda #(.hibyte(strread))
		sta REG_SRC_HI
		lda #(.lobyte(mode_str))
		sta REG_DST_LO
		lda #(.hibyte(mode_str))
		sta REG_DST_HI
		jsr strcpy
		bra change_mode_end

	change_mode_write:
		; set mode string
		lda #(.lobyte(strwrite))
		sta REG_SRC_LO
		lda #(.hibyte(strwrite))
		sta REG_SRC_HI
		lda #(.lobyte(mode_str))
		sta REG_DST_LO
		lda #(.hibyte(mode_str))
		sta REG_DST_HI
		jsr strcpy
		bra change_mode_end

	change_mode_run:
		; set mode string
		lda #(.lobyte(strrun))
		sta REG_SRC_LO
		lda #(.hibyte(strrun))
		sta REG_SRC_HI
		lda #(.lobyte(mode_str))
		sta REG_DST_LO
		lda #(.hibyte(mode_str))
		sta REG_DST_HI
		jsr strcpy
		bra change_mode_end

	change_mode_end:

	stz addr_nibble
	jsr update
	rts



;
; input address or data
; a = key
;
input_address:
	sta input_key

	lda addr_nibble
	and #%00000011
	cmp #$00
	beq set_addr_nibble_0
	cmp #$01
	beq set_addr_nibble_1
	cmp #$02
	beq set_addr_nibble_2
	cmp #$03
	beq set_addr_nibble_3
	bra set_addr_nibble_end

	set_addr_nibble_0:
		asl input_key
		asl input_key
		asl input_key
		asl input_key
		clc

		lda addr_hi
		and #$0f
		ora input_key
		sta addr_hi
		bra set_addr_nibble_end

	set_addr_nibble_1:
		lda addr_hi
		and #$f0
		ora input_key
		sta addr_hi
		bra set_addr_nibble_end

	set_addr_nibble_2:
		asl input_key
		asl input_key
		asl input_key
		asl input_key
		clc

		lda addr_lo
		and #$0f
		ora input_key
		sta addr_lo
		bra set_addr_nibble_end

	set_addr_nibble_3:
		lda addr_lo
		and #$f0
		ora input_key
		sta addr_lo
		;bra set_addr_nibble_end

	set_addr_nibble_end:

	; set next address nibble
	inc addr_nibble

	; convert address to string
	lda #(.lobyte(addr_str))
	sta REG_DST_LO
	lda #(.hibyte(addr_str))
	sta REG_DST_HI
	lda #(.lobyte(addr_lo))
	sta REG_SRC_LO
	lda #(.hibyte(addr_lo))
	sta REG_SRC_HI
	ldy #$00
	jsr u16tostr_hex

	jsr update
	rts



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
	bcc end_isr
	rol ; c == bit6, timer 1
	bcs end_isr
	rol ; c == bit5, timer 2
	bcs end_isr
	rol ; c == bit4, cb1 -> keys irq
	bcs keys_isr
	rol ; c == bit5, cb2 -> keypad irq
	bcs keypad_isr
	bra end_isr

	; individual key pressed
	keys_isr:
		; read data pins
		lda KEYS_IO_PORT
		and #KEYS_IO_MASK

		jsr change_mode

		bra end_isr

	; key on keypad pressed
	keypad_isr:
		jsr keypad_disable_irq

		lda #KEYPAD_INIT_DELAY
		jsr sleep_1

		ldx #$01  ; currently polled key
		cb2_isr_input_loop:
			; create a falling clock edge
			lda #KEYPAD_IO_PIN_CLK     ; clk = 1
			sta KEYPAD_IO_PORT
			lda #KEYPAD_PULSE_DELAY
			jsr sleep
			lda #$00                   ; clk = 0
			sta KEYPAD_IO_PORT
			lda #KEYPAD_PULSE_DELAY
			jsr sleep

			; read data pin
			lda KEYPAD_IO_PORT
			and #KEYPAD_IO_PIN_DAT
			cmp #KEYPAD_IO_PIN_DAT     ; active low
			beq cb2_isr_no_key_pressed

			txa
			cmp #$10  ; treat key '16' as '0'
			bne cb2_isr_input_not_0
			lda #$00
			cb2_isr_input_not_0:

			jsr input_address
			bra cb2_isr_input_loop_end ; no multi-key presses

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
