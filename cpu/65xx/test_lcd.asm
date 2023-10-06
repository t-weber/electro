;
; lcd test
; @author Tobias Weber
; @date 24-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"



sleep:
	phy
	phx

	ldx #$40
	sleep_loop_x:
		ldy #$ff
		sleep_loop_y:
			dey
			bne sleep_loop_y
		dex
		bne sleep_loop_x

	plx
	ply
	rts



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

	jsr lcd_init

	; ---------------------------------------------------------------------
	; write text
	ldx #'A'
	jsr lcd_send_byte
	ldx #'B'
	jsr lcd_send_byte
	ldx #'C'
	jsr lcd_send_byte
	ldx #'D'
	jsr lcd_send_byte
	; ---------------------------------------------------------------------

	stp
	rts
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; lcd interface
; -----------------------------------------------------------------------------
lcd_init:
	lda #LCD_IO_PINS
	sta LCD_IO_PORT_WR

	; ---------------------------------------------------------------------
	; init
	jsr sleep
	ldx #%00000011
	jsr lcd_send_nibble_cmd

	jsr sleep
	ldx #%00000011
	jsr lcd_send_nibble_cmd

	jsr sleep
	ldx #%00000011
	jsr lcd_send_nibble_cmd

	ldx #%00000010
	jsr lcd_send_nibble_cmd
	; ---------------------------------------------------------------------

	jsr lcd_function
	jsr lcd_display
	jsr lcd_clear
	jsr lcd_return
	jsr lcd_caret_dir
	jsr lcd_address

	rts


;
; clear display
;
lcd_clear:
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%00000001
	jsr lcd_send_nibble_cmd

	jsr sleep
	rts


;
; caret return
;
lcd_return:
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%00000010
	jsr lcd_send_nibble_cmd

	jsr sleep
	rts


;
; set caret direction
;
lcd_caret_dir:
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%00000110
	jsr lcd_send_nibble_cmd
	rts


;
; set display
;
lcd_display:
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%00001111
	jsr lcd_send_nibble_cmd
	rts


;
; set address
;
lcd_address:
	; high nibble
	ldx #%00001000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%00000110
	jsr lcd_send_nibble_cmd
	rts


;
; set function
;
lcd_function:
	; high nibble
	ldx #%00000010
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%00001000
	jsr lcd_send_nibble_cmd
	rts


;
; shift display
;
lcd_shift:
	; high nibble
	ldx #%00000001
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%00000100
	jsr lcd_send_nibble_cmd
	rts


;
; x = data
; send a nibble to the command register
;
lcd_send_nibble_cmd:
	; write data without enable bit
	stx LCD_IO_PORT

	; write data with enable bit
	txa
	ora #LCD_PIN_ENABLE
	sta LCD_IO_PORT
	jsr sleep

	; write data without enable bit
	stx LCD_IO_PORT
	rts


;
; send a nibble to the display buffer
; x = data
;
lcd_send_nibble:
	; write data without enable bit
	txa
	ora #LCD_PIN_RS
	sta LCD_IO_PORT

	; write data with enable bit
	txa
	ora #(LCD_PIN_ENABLE | LCD_PIN_RS)
	sta LCD_IO_PORT
	jsr sleep

	; write data without enable bit
	txa
	ora #LCD_PIN_RS
	sta LCD_IO_PORT
	rts


;
; send a byte to the display buffer
; x = data
;
lcd_send_byte:
	; write high nibble
	phx
	txa
	ror
	ror
	ror
	ror
	and #$0f
	tax
	jsr lcd_send_nibble

	; write low nibble
	pla
	and #$0f
	tax
	jsr lcd_send_nibble
	rts
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; interrupt service routines
; -----------------------------------------------------------------------------
nmi_main:
	pha
	phx
	phy

	ldx #'X'
	jsr lcd_send_byte

	ply
	plx
	pla
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
