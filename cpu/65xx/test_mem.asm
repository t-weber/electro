;
; memory test program
; @author Tobias Weber
; @date 16-sep-2023
; @license see 'LICENSE' file
;

.include "defs.inc"


; -----------------------------------------------------------------------------
; memory test
; -----------------------------------------------------------------------------
START_PAGE    = $01
END_PAGE      = $80
TEST_PATTERN1 = %10101010
TEST_PATTERN2 = %01010101

; page address (in litte endian)
page_ptr_1     = $0001
page_ptr_2     = $0000
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; entry point
; -----------------------------------------------------------------------------
main:
	; init
	sei
	clc
	cld
	clv

	; stack pointer relative to STACK_PAGE -> 0x01ff
	ldx #$ff
	txs

test_start:
	; output status to port 1
	lda #$ff
	sta IO_PORT1_WR
	lda #%00000000
	sta IO_PORT1

	; ---------------------------------------------------------------------
	; write to and read from the same memory cell
	; ---------------------------------------------------------------------
	; test zero page memory
	ldx #$00
	ldy #$00
	addr_loop_zp:
		; write test pattern 1
		lda #TEST_PATTERN1
		sta ZERO_PAGE, y

		; read test pattern 1 back in
		lda #$00
		lda ZERO_PAGE, y
		cmp #TEST_PATTERN1
		bne test_error_zp

		; write test pattern 2
		lda #TEST_PATTERN2
		sta ZERO_PAGE, y

		; read test pattern 2 back in
		lda #$00
		lda ZERO_PAGE, y
		cmp #TEST_PATTERN2
		bne test_error_zp

		iny
		cpy #$00
		bne addr_loop_zp

	; bne above can't jump test_error directly
	jmp after_test_error_zp
	test_error_zp:
		jmp test_error
	after_test_error_zp:

	; output status to port 1
	lda #%00000001
	sta IO_PORT1

	; test the rest of the memory
	ldx #START_PAGE
	page_loop:
		ldy #$00
		sty page_ptr_2
		stx page_ptr_1

		ldy #$00
		addr_loop:
			; write test pattern 1
			lda #TEST_PATTERN1
			sta (page_ptr_2), y

			; read test pattern 1 back in
			lda #$00
			lda (page_ptr_2), y
			cmp #TEST_PATTERN1
			bne test_error

			; write test pattern 2
			lda #TEST_PATTERN2
			sta (page_ptr_2), y

			; read test pattern 2 back in
			lda #$00
			lda (page_ptr_2), y
			cmp #TEST_PATTERN2
			bne test_error

			iny
			cpy #$00
			bne addr_loop
		inx
		cpx #END_PAGE
		bne page_loop

	; output status to port 1
	lda #%00000011
	sta IO_PORT1
	; ---------------------------------------------------------------------

	; ---------------------------------------------------------------------
	; write to all memory cells and then read them all
	; ---------------------------------------------------------------------
	; test zero page memory
	ldx #$00
	ldy #$00
	addr_loop_zp_write:
		; write test pattern 1
		lda #TEST_PATTERN1
		sta ZERO_PAGE, y

		iny
		cpy #$00
		bne addr_loop_zp_write

	ldy #$00
	addr_loop_zp_read:
		; read test pattern 1 back in
		lda #$00
		lda ZERO_PAGE, y
		cmp #TEST_PATTERN1
		bne test_error

		iny
		cpy #$00
		bne addr_loop_zp_read

	; output status to port 1
	lda #%00000111
	sta IO_PORT1

	; test the rest of the memory
	ldx #START_PAGE
	page_loop_write:
		ldy #$00
		sty page_ptr_2
		stx page_ptr_1

		ldy #$00
		addr_loop_write:
			; write test pattern 1
			lda #TEST_PATTERN1
			sta (page_ptr_2), y

			iny
			cpy #$00
			bne addr_loop_write
		inx
		cpx #END_PAGE
		bne page_loop_write

	ldx #START_PAGE
	page_loop_read:
		ldy #$00
		sty page_ptr_2
		stx page_ptr_1

		ldy #$00
		addr_loop_read:
			; read test pattern 1 back in
			lda #$00
			lda (page_ptr_2), y
			cmp #TEST_PATTERN1
			bne test_error

			iny
			cpy #$00
			bne addr_loop_read
		inx
		cpx #END_PAGE
		bne page_loop_read

	; output status to port 1
	lda #%00001111
	sta IO_PORT1
	; ---------------------------------------------------------------------

	; loop tests
	jmp test_start
	;jmp test_end

	; handle test errors
	test_error:
		; output error page number to port 1
		stx IO_PORT1

		ldy #$c0
		error_blink_loop_1a:
			lda #$ff
			error_blink_loop_1:
				dec
				bne error_blink_loop_1
			dey
			bne error_blink_loop_1a

		; output error status to port 1
		lda #%11111111
		sta IO_PORT1

		ldy #$c0
		error_blink_loop_2a:
			lda #$ff
			error_blink_loop_2:
				dec
				bne error_blink_loop_2
			dey
			bne error_blink_loop_2a

		jmp test_error

	test_end:
		stp
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
