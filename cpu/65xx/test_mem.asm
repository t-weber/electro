;
; memory test program
; @author Tobias Weber
; @date 16-sep-2023
; @license see 'LICENSE' file
;

; -----------------------------------------------------------------------------
; memory layout
; -----------------------------------------------------------------------------
ZERO_PAGE     = $0000
STACK_PAGE    = $0100
IO_START      = $c000
ROM_START     = $e000
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; I/O registers, see: https://en.wikipedia.org/wiki/WDC_65C22
; -----------------------------------------------------------------------------
IO_PORT1      = $c001
IO_PORT2      = $c000
IO_PORT1_WR   = $c003
IO_PORT2_WR   = $c002
IO_AUX_CTRL   = $c00b
IO_PORTS_CTRL = $c00c
IO_INT_FLAGS  = $c00d
IO_INT_ENABLE = $c00e
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; memory test
; -----------------------------------------------------------------------------
START_PAGE    = $01
END_PAGE      = $c0
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

	; output status to port 1
	lda #$ff
	sta IO_PORT1_WR
	lda #%01111111
	sta IO_PORT1

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
		bne test_error

		; write test pattern 2
		lda #TEST_PATTERN2
		sta ZERO_PAGE, y

		; read test pattern 2 back in
		lda #$00
		lda ZERO_PAGE, y
		cmp #TEST_PATTERN2
		bne test_error

		iny
		cpy #$00
		bne addr_loop_zp

	; output status to port 1
	lda #%00111111
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
	lda #%00011111
	sta IO_PORT1

	jmp end_test
	test_error:
		; output error page number to port 1
		stx IO_PORT1

		; output error status to port 1
		;lda #%11111111
		;sta IO_PORT1

	end_test:
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
