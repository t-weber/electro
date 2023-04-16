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
		input [3:0] in_digit,
		output [6:0] out_leds
	);

wire [6:0] leds;

// constants, see: https://en.wikipedia.org/wiki/Seven-segment_display
//localparam [6:0] ledvec[2*16-1 : 0] =
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

assign leds =
	(in_digit == 4'h0) ? ledvec[inverse_numbering*16*7 + 1*7 - 1 -: 7] :
	(in_digit == 4'h1) ? ledvec[inverse_numbering*16*7 + 2*7 - 1 -: 7] :
	(in_digit == 4'h2) ? ledvec[inverse_numbering*16*7 + 3*7 - 1 -: 7] :
	(in_digit == 4'h3) ? ledvec[inverse_numbering*16*7 + 4*7 - 1 -: 7] :
	(in_digit == 4'h4) ? ledvec[inverse_numbering*16*7 + 5*7 - 1 -: 7] :
	(in_digit == 4'h5) ? ledvec[inverse_numbering*16*7 + 6*7 - 1 -: 7] :
	(in_digit == 4'h6) ? ledvec[inverse_numbering*16*7 + 7*7 - 1 -: 7] :
	(in_digit == 4'h7) ? ledvec[inverse_numbering*16*7 + 8*7 - 1 -: 7] :
	(in_digit == 4'h8) ? ledvec[inverse_numbering*16*7 + 9*7 - 1 -: 7] :
	(in_digit == 4'h9) ? ledvec[inverse_numbering*16*7 + 10*7 - 1 -: 7] :
	(in_digit == 4'ha) ? ledvec[inverse_numbering*16*7 + 11*7 - 1 -: 7] :
	(in_digit == 4'hb) ? ledvec[inverse_numbering*16*7 + 12*7 - 1 -: 7] :
	(in_digit == 4'hc) ? ledvec[inverse_numbering*16*7 + 13*7 - 1 -: 7] :
	(in_digit == 4'hd) ? ledvec[inverse_numbering*16*7 + 14*7 - 1 -: 7] :
	(in_digit == 4'he) ? ledvec[inverse_numbering*16*7 + 15*7 - 1 -: 7] :
	(in_digit == 4'hf) ? ledvec[inverse_numbering*16*7 + 16*7 - 1 -: 7] :
	7'h00;

generate if(zero_is_on)
	assign out_leds = ~leds;
else
	assign out_leds = leds;
endgenerate

endmodule
