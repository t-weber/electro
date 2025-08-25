/**
 * compose a word by selecting bytes from two different words
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 23-aug-2025
 * @license see 'LICENSE' file
 */

`default_nettype /*wire*/ none


module memsel
#(
	parameter WORD_BITS = 32,
	parameter BYTE_BITS = 8,
	parameter SEL_BITS = WORD_BITS / BYTE_BITS
)
(
	input wire [WORD_BITS - 1 : 0] in_word_1,
	input wire [WORD_BITS - 1 : 0] in_word_2,
	input wire [SEL_BITS - 1 : 0] in_sel,

	output wire [WORD_BITS - 1 : 0] out_word
);


genvar byte_idx;
generate
	for(byte_idx = 0; byte_idx < SEL_BITS; ++byte_idx) begin
		assign out_word[(byte_idx + 1)*BYTE_BITS - 1 : byte_idx*BYTE_BITS] = (
			in_sel[byte_idx]
				? in_word_1[(byte_idx + 1)*BYTE_BITS - 1 : byte_idx*BYTE_BITS]
				: in_word_2[(byte_idx + 1)*BYTE_BITS - 1 : byte_idx*BYTE_BITS]);
	end
endgenerate


endmodule
