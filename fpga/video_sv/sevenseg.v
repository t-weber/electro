//
// seven segment leds
// @author Tobias Weber <tobias.weber@tum.de>
// @date 15-apr-2023
// @license see 'LICENSE' file
//

module sevenseg
	#(
		parameter zero_is_on = 0,
		parameter inverse_numbering = 0
	)
	(
		input wire [3:0] in_digit,
		output wire [6:0] out_leds
	);

// constants, see: https://en.wikipedia.org/wiki/Seven-segment_display
localparam [0 : 7*2*16-1] ledvec =
{
	// non-inverted numbering
	7'h7e, 7'h30, 7'h6d, 7'h79, // 0-3
	7'h33, 7'h5b, 7'h5f, 7'h70, // 4-7
	7'h7f, 7'h7b, 7'h77, 7'h1f, // 8-b
	7'h4e, 7'h3d, 7'h4f, 7'h47,  // c-f

	// inverted numbering
	7'h3f, 7'h06, 7'h5b, 7'h4f, // 0-3
	7'h66, 7'h6d, 7'h7d, 7'h07, // 4-7
	7'h7f, 7'h6f, 7'h77, 7'h7c, // 8-b
	7'h39, 7'h5e, 7'h79, 7'h71  // c-f
};

wire [6:0] leds;
assign leds = ledvec[inverse_numbering*16*7 + (in_digit+1)*7 - 1 -: 7];

generate if(zero_is_on)
	assign out_leds = ~leds;
else
	assign out_leds = leds;
endgenerate

endmodule
