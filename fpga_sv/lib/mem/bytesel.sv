/**
 * get a byte from a word
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 14-september-2025
 * @license see 'LICENSE' file
 */

`default_nettype /*wire*/ none


module bytesel
#(
	parameter WORD_BITS = 32,
	parameter BYTE_BITS = 8,
	parameter IDX_BITS  = $clog2(WORD_BITS) - $clog2(BYTE_BITS),

	parameter LITTLE_ENDIAN = 1
)
(
	input wire [WORD_BITS - 1 : 0] in_word,
	input wire [IDX_BITS - 1 : 0] in_idx,

	output wire [BYTE_BITS - 1 : 0] out_byte
);


generate
	if(LITTLE_ENDIAN != 0)
		assign out_byte[BYTE_BITS - 1 : 0] = in_word[in_idx*BYTE_BITS +: BYTE_BITS];
	else
		assign out_byte[BYTE_BITS - 1 : 0] = in_word[((1 << IDX_BITS) - 1 - in_idx)*BYTE_BITS +: BYTE_BITS];
endgenerate

endmodule
