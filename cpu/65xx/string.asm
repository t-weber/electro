;
; string functions
; @author Tobias Weber
; @date 8-oct-2023
; @license see 'LICENSE' file
;

.ifndef __STRING_DEFS__
__STRING_DEFS__ = 1

.include "defs.inc"


;
; copies a zero-terminated string
; REG_SRC = address of source string
; REG_DST = address of destination string
;
strcpy:
	pha
	phy

	ldy #$00
	strcpy_loop:
		; load char
		lda (REG_SRC_LO), y
		sta (REG_DST_LO), y

		; end at terminating zero
		;cmp #$00
		beq strcpy_loop_end

		; next char
		iny
		bra strcpy_loop
	strcpy_loop_end:

	ply
	pla
	rts



;
; concatinates two zero-terminated strings
; REG_SRC = address of source string
; REG_DST = address of destination string
;
strcat:
	pha
	phx
	phy

	; find end of destination string
	ldy #$00  ; index into destination string
	strcat_loop_findend:
		; load char
		lda (REG_DST_LO), y

		; end at terminating zero
		;cmp #$00
		beq strcat_loop_findend_end

		; next char
		iny
		bra strcat_loop_findend
	strcat_loop_findend_end:

	; add source string to the end of destination string
	ldx #$00  ; index into source string
	strcat_loop:
		; load char
		phy                   ; save y
		txa                   ; x -> a -> y
		tay                   ;
		lda (REG_SRC_LO), y
		ply                   ; restore y
		sta (REG_DST_LO), y

		; end at terminating zero
		cmp #$00
		beq strcat_loop_end

		; next char
		iny
		inx
		bra strcat_loop
	strcat_loop_end:

	ply
	plx
	pla
	rts



;
; convert an unsigned 4-bit integer to a string
; a = integer
; REG_DST + y = address of destination string
;
u4tostr_hex:
	;and #$0f
	cmp #$0a                      ; a in [0, 9] or [a, f] ?
	bcs u4tostr_hex_a_to_f

	u4tostr_hex_0_to_9:           ; a = '0'..'9'
		adc #'0'
		bra u4tostr_hex_end

	u4tostr_hex_a_to_f:           ; a = 'a'..'f'
		adc #('A' - $0a - 1)  ; -1 comes from the carry flag
		;bra u4tostr_hex_end

	u4tostr_hex_end:
		sta (REG_DST_LO), y

	rts



;
; convert an unsigned 8-bit integer to a string
; a = integer
; REG_DST + y = address of destination string
;
u8tostr_hex:
	phy

	; high nibble
	pha
	ror
	ror
	ror
	ror
	and #$0f
	jsr u4tostr_hex

	; low nibble
	pla
	and #$0f
	iny
	jsr u4tostr_hex

	; zero at end
	iny
	lda #$00
	sta (REG_DST_LO), y

	ply
	rts



;
; convert an unsigned 16-bit integer to a string
; REG_SRC = address of 16-bit integer
; REG_DST = address of destination string
;
u16tostr_hex:
	phy

	; byte 1
	ldy #$01
	lda (REG_SRC_LO), y
	ldy #$00
	jsr u8tostr_hex

	; byte 2
	ldy #$00
	lda (REG_SRC_LO), y
	ldy #$02
	jsr u8tostr_hex

	; zero at end
	ldy #$04
	lda #$00
	sta (REG_DST_LO), y

	ply
	rts



;
; convert an unsigned 32-bit integer to a string
; REG_SRC = address of 32-bit integer
; REG_DST = address of destination string
;
u32tostr_hex:
	phy

	; byte 1
	ldy #$03
	lda (REG_SRC_LO), y
	ldy #$00
	jsr u8tostr_hex

	; byte 2
	ldy #$02
	lda (REG_SRC_LO), y
	ldy #$02
	jsr u8tostr_hex

	; byte 3
	ldy #$01
	lda (REG_SRC_LO), y
	ldy #$04
	jsr u8tostr_hex

	; byte 3
	ldy #$00
	lda (REG_SRC_LO), y
	ldy #$06
	jsr u8tostr_hex

	; zero at end
	ldy #$08
	lda #$00
	sta (REG_DST_LO), y

	ply
	rts



;
; convert an unsigned N-byte integer to a string
; REG_SRC = address of N-byte integer
; REG_DST = address of destination string
; x = number of bytes in integer
;
uNtostr_hex:
	phy

	stx REG_IDX_1                 ; byte index into integer
	dec REG_IDX_1                 ;
	stz REG_IDX_2                 ; string index

	uNtostr_hex_loop:
		ldy REG_IDX_1
		lda (REG_SRC_LO), y
		ldy REG_IDX_2
		jsr u8tostr_hex

		dec REG_IDX_1
		inc REG_IDX_2
		inc REG_IDX_2

		lda REG_IDX_1
		cmp #$ff              ; has the index wrapped around?
		bne uNtostr_hex_loop
		;bra uNtostr_hex_end

	uNtostr_hex_end:
		; zero at end
		ldy REG_IDX_2
		lda #$00
		sta (REG_DST_LO), y

	ply
	rts



;
; convert an unsigned N-byte integer to a string
; big endian version (not reversed)
; REG_SRC = address of N-byte integer
; REG_DST = address of destination string
; x = number of bytes in integer
;
uNtostr_hex_be:
	phy

	stz REG_IDX_1  ; byte index into integer
	stz REG_IDX_2  ; string index
	stx REG_IDX_3  ; number of bytes

	uNtostr_hex_be_loop:
		ldy REG_IDX_1
		lda (REG_SRC_LO), y
		ldy REG_IDX_2
		jsr u8tostr_hex

		inc REG_IDX_1
		inc REG_IDX_2
		inc REG_IDX_2

		lda REG_IDX_1
		cmp REG_IDX_3
		bne uNtostr_hex_be_loop
		;bra uNtostr_hex_be_end

	uNtostr_hex_be_end:
		; zero at end
		ldy REG_IDX_2
		lda #$00
		sta (REG_DST_LO), y

	ply
	rts



.endif
