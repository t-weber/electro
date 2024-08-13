/**
 * converts nibble(s) to hex char(s)
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 13-aug-2024
 * @license see 'LICENSE' file
 */


module hexchar
#(
	parameter CHAR_SIZE  = 8,
	parameter DIGIT_SIZE = 4
 )
(
	input wire [DIGIT_SIZE - 1 : 0] in_digit,
	output wire [CHAR_SIZE - 1 : 0] out_char
);


logic [0 : 15][CHAR_SIZE - 1 : 0] vec =
{
	"0", "1", "2", "3",
	"4", "5", "6", "7",
	"8", "9", "a", "b",
	"c", "d", "e", "f"
};


assign out_char = vec[in_digit];


endmodule


// ----------------------------------------------------------------------------


module hexchars
#(
	parameter NUM_CHARS  = 2,

	parameter CHAR_SIZE  = 8,
	parameter DIGIT_SIZE = 4
 )
(
	input wire [DIGIT_SIZE*NUM_CHARS - 1 : 0] in_digits,
	output wire [CHAR_SIZE*NUM_CHARS - 1 : 0] out_chars
);


genvar char_idx;
generate
for(char_idx = 0; char_idx < NUM_CHARS; ++char_idx)
begin
	hexchar #(
		.CHAR_SIZE(CHAR_SIZE),
		.DIGIT_SIZE(DIGIT_SIZE)
	)
	char_mod(
		.in_digit(in_digits[(NUM_CHARS - char_idx)*DIGIT_SIZE - 1 -: DIGIT_SIZE]),
		.out_char(out_chars[(char_idx + 1)*CHAR_SIZE - 1 -: CHAR_SIZE])
	);
end
endgenerate


endmodule
