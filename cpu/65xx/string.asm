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
		phy  ; save y
		txa  ; x -> a -> y
		tay  ;
		lda (REG_SRC_LO), y
		ply  ; restore y
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
	cmp #$00
	beq u4tostr_hex_0
	cmp #$01
	beq u4tostr_hex_1
	cmp #$02
	beq u4tostr_hex_2
	cmp #$03
	beq u4tostr_hex_3
	cmp #$04
	beq u4tostr_hex_4
	cmp #$05
	beq u4tostr_hex_5
	cmp #$06
	beq u4tostr_hex_6
	cmp #$07
	beq u4tostr_hex_7
	cmp #$08
	beq u4tostr_hex_8
	cmp #$09
	beq u4tostr_hex_9
	cmp #$0a
	beq u4tostr_hex_a
	cmp #$0b
	beq u4tostr_hex_b
	cmp #$0c
	beq u4tostr_hex_c
	cmp #$0d
	beq u4tostr_hex_d
	cmp #$0e
	beq u4tostr_hex_e
	cmp #$0f
	beq u4tostr_hex_f
	bra u4tostr_hex_end

	u4tostr_hex_0:
		lda #'0'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_1:
		lda #'1'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_2:
		lda #'2'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_3:
		lda #'3'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_4:
		lda #'4'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_5:
		lda #'5'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_6:
		lda #'6'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_7:
		lda #'7'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_8:
		lda #'8'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_9:
		lda #'9'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_a:
		lda #'A'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_b:
		lda #'B'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_c:
		lda #'C'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_d:
		lda #'D'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_e:
		lda #'E'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_f:
		lda #'F'
		sta (REG_DST_LO), y
		bra u4tostr_hex_end
	u4tostr_hex_end:

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



.endif
