;
; lcd functions
; @author Tobias Weber
; @date 24-sep-2023
; @license see 'LICENSE' file
;

.ifndef __LCD_DEFS__
__LCD_DEFS__ = 1

.include "defs.inc"
.include "init.asm"
.include "sleep.asm"


; -----------------------------------------------------------------------------
; lcd interface
; @see https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
; -----------------------------------------------------------------------------
lcd_init:
	lda #LCD_IO_PINS_WR
	sta LCD_IO_PORT_WR

	; ---------------------------------------------------------------------
	; init
	lda #(20 * LCD_SLEEP_BASE)
	jsr sleep
	ldx #%0000_0011
	jsr lcd_send_nibble_cmd

	lda #(5 * LCD_SLEEP_BASE)
	jsr sleep
	ldx #%0000_0011
	jsr lcd_send_nibble_cmd

	lda #(LCD_SLEEP_BASE)
	jsr sleep
	ldx #%0000_0011
	jsr lcd_send_nibble_cmd

	ldx #%0000_0010
	jsr lcd_send_nibble_cmd
	; ---------------------------------------------------------------------

	; setup
	jsr lcd_function
	jsr lcd_display
	jsr lcd_caret_dir
	jsr lcd_clear
	jsr lcd_return

	ldx #$00
	jsr lcd_address

	rts


;
; clear display
;
lcd_clear:
	; high nibble
	ldx #%0000_0000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%0000_0001
	jsr lcd_send_nibble_cmd

	; wait
	lda #(2 * LCD_SLEEP_BASE)
	jsr sleep

	rts


;
; caret return
;
lcd_return:
	; high nibble
	ldx #%0000_0000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #%0000_0010
	jsr lcd_send_nibble_cmd

	; wait
	lda #(2 * LCD_SLEEP_BASE)
	jsr sleep

	rts


;
; set caret direction
;
lcd_caret_dir:
	; high nibble
	ldx #%0000_0000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #(%0000_0100 | LCD_CARET_DIR_INC)
	jsr lcd_send_nibble_cmd

	rts


;
; set display properties
;
lcd_display:
	; high nibble
	ldx #%0000_0000
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #(%0000_1000 | LCD_DISP_ON | LCD_DISP_CARET_LINE)
	jsr lcd_send_nibble_cmd

	rts


;
; set address for display buffer
; a = address (line 2 starts at LCD_LINE_LEN)
;
lcd_address:
	; high nibble
	pha
	lsr
	lsr
	lsr
	lsr
	and #$0f
	ora #%0000_1000
	tax
	jsr lcd_send_nibble_cmd

	; low nibble
	pla
	and #$0f
	tax
	jsr lcd_send_nibble_cmd

	rts


;
; set function
;
lcd_function:
	; high nibble
	ldx #%0000_0010
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #LCD_FUNC_2LINES
	jsr lcd_send_nibble_cmd

	rts


;
; shift caret right
;
lcd_shift_caret_right:
	; high nibble
	ldx #%0000_0001
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #LCD_SHIFT_RIGHT
	jsr lcd_send_nibble_cmd

	rts


;
; shift caret left
;
lcd_shift_caret_left:
	; high nibble
	ldx #%0000_0001
	jsr lcd_send_nibble_cmd

	; low nibble
	ldx #$00
	jsr lcd_send_nibble_cmd

	rts


;
; send a nibble to the command register
; x = data
;
lcd_send_nibble_cmd:
	; write data without enable bit
	stx LCD_IO_PORT

	; write data with enable bit
	txa
	ora #LCD_PIN_ENABLE
	sta LCD_IO_PORT
	lda #(LCD_SLEEP_BASE)
	jsr sleep

	; write data without enable bit
	stx LCD_IO_PORT
	lda #(LCD_SLEEP_BASE)
	jsr sleep

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
	lda #(LCD_SLEEP_BASE)
	jsr sleep

	; write data without enable bit
	txa
	ora #LCD_PIN_RS
	sta LCD_IO_PORT
	lda #(LCD_SLEEP_BASE)
	jsr sleep

	rts


;
; send a byte to the display buffer
; x = data
;
lcd_send_byte:
	; write high nibble
	phx
	txa
	lsr
	lsr
	lsr
	lsr
	and #$0f
	tax
	jsr lcd_send_nibble

	; write low nibble
	pla
	and #$0f
	tax
	jsr lcd_send_nibble

	rts


;
; prints a zero-terminated string
; REG_SRC = address of string
;
lcd_print:
	pha
	phx
	phy

	ldy #$00
	lcd_print_loop:
		; load char
		lda (REG_SRC_LO), y
		; end at terminating zero
		beq lcd_print_loop_end

		; print char
		tax
		jsr lcd_send_byte

		; next char
		iny
		bra lcd_print_loop
	lcd_print_loop_end:

	ply
	plx
	pla
	rts
; -----------------------------------------------------------------------------


.endif
