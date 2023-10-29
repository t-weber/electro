;
; system monitor
; @author Tobias Weber
; @date 29-oct-2023
; @license see 'LICENSE' file
;

.include "defs.inc"
.include "keypad.asm"
.include "lcd.asm"
.include "string.asm"
.include "sleep.asm"

SHOW_SPLASH_SCREEN = 1
INCLUDE_RUN_TEST   = 1


; constants
strread:   .asciiz "READ  "
strwrite:  .asciiz "WRITE "
strrun:    .asciiz "RUN   "
straddr:   .asciiz "ADDR "
strdata:   .asciiz "DATA "

.ifdef SHOW_SPLASH_SCREEN
strtitle:  .asciiz "Monitor for 65xx"
strauthor: .asciiz "2023 by T. Weber"
.endif

mode_read    = KEYS_PIN_1             ; read from memory
mode_write   = KEYS_PIN_2             ; write to memory
mode_run     = KEYS_PIN_3             ; jump to address
mode_func    = KEYS_PIN_4             ; context-sensitive button

submode_addr = %0000_0000             ; write address
submode_data = %0000_0001             ; write data

data_len     = LCD_CHAR_LEN / 2       ; number of data bytes to print


; variables
mode         = USERMEM_START + $0000  ; program mode: read/write/run
sub_mode     = USERMEM_START + $0001  ; address or data input mode
input_key    = USERMEM_START + $0002  ; current input key

addr_lo      = USERMEM_START + $0003  ; current address
addr_hi      = USERMEM_START + $0004  ;
addr_nibble  = USERMEM_START + $0005  ; current nibble for address input
data_nibble  = USERMEM_START + $0006  ; current nibble for data input
data_byte    = USERMEM_START + $0007  ; current byte for data input

mode_str     = USERMEM_START + $0010  ; mode as string
submode_str  = USERMEM_START + $0020  ; sub-mode as string
addr_str     = USERMEM_START + $0030  ; address as string
data_str     = USERMEM_START + $0040  ; data as string



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

	; initialise modules
	jsr ports_reset
	jsr sleep_init
	jsr lcd_init
	jsr keys_init
	jsr keypad_init

	; clear lcd
	jsr lcd_clear
	jsr lcd_return

.ifdef SHOW_SPLASH_SCREEN
	jsr splash_screen
.endif

	; initialise variables
	stz mode
	inc mode
	stz sub_mode
	stz addr_lo
	stz addr_hi
	stz addr_nibble
	stz data_nibble
	stz data_byte
	stz mode_str
	stz submode_str
	stz addr_str
	stz data_str

	; set initial mode to read
	lda #mode_read
	jsr change_mode

	; ---------------------------------------------------------------------
	; wait for keypad input
	; ---------------------------------------------------------------------
	main_loop:
		wai
		bra main_loop
	; ---------------------------------------------------------------------
	;rts
; -----------------------------------------------------------------------------



.ifdef SHOW_SPLASH_SCREEN
splash_screen:
	; print the title string
	lda #(.lobyte(strtitle))
	sta REG_SRC_LO
	lda #(.hibyte(strtitle))
	sta REG_SRC_HI
	jsr lcd_print

	; next line on lcd
	lda #LCD_LINE_LEN
	jsr lcd_address

	; print the author string
	lda #(.lobyte(strauthor))
	sta REG_SRC_LO
	lda #(.hibyte(strauthor))
	sta REG_SRC_HI
	jsr lcd_print

	lda #$0f
	jsr sleep_3

	rts
.endif



;
; update the output on the lcd
;
update_output:
	; ---------------------------------------------------------------------
	; prepare strings
	; ---------------------------------------------------------------------
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

	; read data at given address
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
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; output strings to lcd
	; ---------------------------------------------------------------------
	jsr lcd_clear
	jsr lcd_return

	; print the mode string
	lda #(.lobyte(mode_str))
	sta REG_SRC_LO
	lda #(.hibyte(mode_str))
	sta REG_SRC_HI
	jsr lcd_print

	; print the sub-mode string
	lda #(.lobyte(submode_str))
	sta REG_SRC_LO
	lda #(.hibyte(submode_str))
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

	; set caret to current input position
	lda sub_mode
	cmp #submode_addr
	beq update_output_submode_addr
	bra update_output_submode_data

	update_output_submode_addr:
		clc
		lda addr_nibble
		and #%0000_0011
		adc #11
		jsr lcd_address
		bra update_output_submode_end

	update_output_submode_data:
		clc
		lda data_nibble
		and #%0000_0001
		adc data_byte
		adc data_byte
		adc #LCD_LINE_LEN
		jsr lcd_address
		;bra update_output_submode_end

	update_output_submode_end:
	; ---------------------------------------------------------------------

	rts



;
; change the program's input mode
; a = mode (key pressed)
;
change_mode:
	; check if only the sub-mode changes
	cmp #mode_func
	beq change_mode_func

	; ---------------------------------------------------------------------
	; set new mode
	; ---------------------------------------------------------------------
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

	change_mode_func:
		jsr exec_func

		bra change_mode_end2

	change_mode_end:
		; reset sub-mode
		stz sub_mode

	change_mode_end2:
		; reset input counters
		stz addr_nibble
		stz data_nibble
		stz data_byte
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; get sub-mode
	; ---------------------------------------------------------------------
	lda sub_mode
	cmp #submode_addr
	beq change_submode_addr
	bra change_submode_data

	change_submode_addr:
		; set sub-mode string
		lda #(.lobyte(straddr))
		sta REG_SRC_LO
		lda #(.hibyte(straddr))
		sta REG_SRC_HI
		lda #(.lobyte(submode_str))
		sta REG_DST_LO
		lda #(.hibyte(submode_str))
		sta REG_DST_HI
		jsr strcpy

		bra change_submode_end

	change_submode_data:
		; set sub-mode string
		lda #(.lobyte(strdata))
		sta REG_SRC_LO
		lda #(.hibyte(strdata))
		sta REG_SRC_HI
		lda #(.lobyte(submode_str))
		sta REG_DST_LO
		lda #(.hibyte(submode_str))
		sta REG_DST_HI
		jsr strcpy

		;bra change_submode_end

	change_submode_end:
	; ---------------------------------------------------------------------

	jsr update_output
	rts



;
; context-sensitive function button has been pressed
;   - read mode:  advance address
;   - write mode: change between address and data input
;   - run mode:   jump to address
;
exec_func:
	lda mode
	cmp #mode_read
	beq exec_func_read
	cmp #mode_write
	beq exec_func_write
	cmp #mode_run
	beq exec_func_run
	bra exec_func_end

	exec_func_read:
		; advance address
		lda addr_lo
		clc
		adc #data_len
		sta addr_lo
		bcc exec_func_end
		inc addr_hi

		bra exec_func_end

	exec_func_write:
		; switch between address or data input
		lda sub_mode
		eor #$01
		and #$01
		sta sub_mode

		bra exec_func_end

	exec_func_run:
		jmp (addr_lo)

	exec_func_end:
	rts



;
; input address or data
; a = key
;
input_address_or_data:
	tax
	lda sub_mode
	beq input_address
	bra input_data

	rts



;
; input address
; x = key
;
input_address:
	stx input_key

	lda addr_nibble
	and #%0000_0011
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

	jsr update_output
	rts



;
; input data
; x = key
;
input_data:
	stx input_key

	lda data_nibble
	and #%0000_0001
	cmp #$00
	beq set_data_nibble_0
	cmp #$01
	beq set_data_nibble_1
	bra set_data_nibble_end

	set_data_nibble_0:
		asl input_key
		asl input_key
		asl input_key
		asl input_key
		clc

		; get data at address
		lda addr_lo
		sta REG_DST_LO
		lda addr_hi
		sta REG_DST_HI

		; write new data to address
		ldy data_byte
		lda (REG_DST_LO), y
		and #$0f
		ora input_key
		sta (REG_DST_LO), y

		bra set_data_nibble_end

	set_data_nibble_1:
		; get data at address
		lda addr_lo
		sta REG_DST_LO
		lda addr_hi
		sta REG_DST_HI

		; write new data to address
		ldy data_byte
		lda (REG_DST_LO), y
		and #$f0
		ora input_key
		sta (REG_DST_LO), y

		;bra set_data_nibble_end

	set_data_nibble_end:

	; set next data nibble
	inc data_nibble
	lda data_nibble
	cmp #$02
	bne input_data_nibble_not_over
	stz data_nibble
	inc data_byte
	input_data_nibble_not_over:

	jsr update_output
	rts



; -----------------------------------------------------------------------------
; interrupt service routines
; -----------------------------------------------------------------------------
nmi_main:
	; re-start monitor
	jmp main

	;rti



isr_main:
	pha
	phx
	phy
	sei

	; get type of interrupt
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

	; ---------------------------------------------------------------------
	; individual key pressed
	; ---------------------------------------------------------------------
	keys_isr:
		; read data pins
		lda KEYS_IO_PORT
		and #KEYS_IO_MASK

		jsr change_mode

		bra end_isr
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; key on keypad pressed
	; ---------------------------------------------------------------------
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
			cmp #$10                   ; treat key '16' as '0'
			bne cb2_isr_input_not_0
			lda #$00
			cb2_isr_input_not_0:

			jsr input_address_or_data
			bra cb2_isr_input_loop_end ; no multi-key presses

			cb2_isr_no_key_pressed:
			inx                        ; next key
			cpx #$11                   ; last key?
			bne cb2_isr_input_loop
			;bra cb2_isr_input_loop_end
		cb2_isr_input_loop_end:

		lda IO_INT_FLAGS
		ora #IO_INT_FLAG_CB2  ; clear ind. keypad irq flag
		sta IO_INT_FLAGS

		jsr keypad_enable_irq
		;bra end_isr
	; ---------------------------------------------------------------------

	end_isr:
	cli
	ply
	plx
	pla

	rti
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; test for 'run' command
; -----------------------------------------------------------------------------
.ifdef INCLUDE_RUN_TEST
COMPILE_AS_MODULE = 1
.include "test_piezo2.asm"

.asciiz "TESTPROG"   ; marker to find entry point more easily
.repeat 8, n
	nop          ; add a bit of margin for manoeuvre for jump
.endrep

run_test_prog:
	jsr piezo_main
	stp
.endif
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; table with entry point function pointers
; -----------------------------------------------------------------------------
.segment "JMPTAB"
	.addr nmi_main
	.addr main
	.addr isr_main
; -----------------------------------------------------------------------------
