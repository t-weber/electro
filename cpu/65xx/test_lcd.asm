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
	jsr lcd_sent_byte_we
	ldx #'B'
	jsr lcd_sent_byte_we
	ldx #'C'
	jsr lcd_sent_byte_we
	ldx #'D'
	jsr lcd_sent_byte_we
	; ---------------------------------------------------------------------

	stp
	rts
; -----------------------------------------------------------------------------



; -----------------------------------------------------------------------------
; lcd interface
; -----------------------------------------------------------------------------
lcd_init:
	; output to port 1 pins: enable, register select, data 7-4
	lda #%00111111
	sta IO_PORT1_WR

	; ---------------------------------------------------------------------
	; init
	jsr sleep
	ldx #%00000011
	jsr lcd_send_nibble

	jsr sleep
	ldx #%00000011
	jsr lcd_send_nibble

	jsr sleep
	ldx #%00000011
	jsr lcd_send_nibble

	ldx #%00000010
	jsr lcd_send_nibble
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; set function
	; high nibble
	ldx #%00000010
	jsr lcd_send_nibble

	; low nibble
	ldx #%00001000
	jsr lcd_send_nibble
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; set display
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble

	; low nibble
	ldx #%00001110
	jsr lcd_send_nibble
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; clear
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble

	; low nibble
	ldx #%00000001
	jsr lcd_send_nibble
	jsr sleep
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; return
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble

	; low nibble
	ldx #%00000010
	jsr lcd_send_nibble
	jsr sleep
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; caret direction
	; high nibble
	ldx #%00000000
	jsr lcd_send_nibble

	; low nibble
	ldx #%00000110
	jsr lcd_send_nibble
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; set address
	; high nibble
	ldx #%00001000
	jsr lcd_send_nibble

	; low nibble
	ldx #%00000110
	jsr lcd_send_nibble
	; ---------------------------------------------------------------------

	rts


; x = data
lcd_send_nibble:
	; write data without enable bit
	stx IO_PORT1

	; write data with enable bit
	txa
	ora #%00100000
	sta IO_PORT1
	jsr sleep

	; write data without enable bit
	stx IO_PORT1
	rts


; x = data
lcd_send_nibble_we:
	; write data without enable bit
	txa
	ora #%00010000
	sta IO_PORT1

	; write data with enable bit
	txa
	ora #%00110000
	sta IO_PORT1
	jsr sleep

	; write data without enable bit
	txa
	ora #%00010000
	sta IO_PORT1
	rts


; x = data
lcd_sent_byte_we:
	; write high nibble
	phx
	;stx $0000   ; temporary storage of data byte
	txa
	ror
	ror
	ror
	ror
	and #$0f
	tax
	jsr lcd_send_nibble_we

	; write low nibble
	pla
	;lda $0000   ; temporary storage of data byte
	and #$0f
	tax
	jsr lcd_send_nibble_we
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
	jsr lcd_sent_byte_we

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
