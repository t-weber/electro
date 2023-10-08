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


.endif
