/**
 * multiplier test
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 1-May-2023
 * @license see 'LICENSE' file
 */


module multiplier_test
(
	input wire clock,
	input wire [1 : 0] key,
	output wire [6 : 0] hex0, hex1, hex2, hex3,
	output wire [0 : 0] ledr
);

	localparam IN_BITS = 8;
	localparam OUT_BITS = 16;

	wire [IN_BITS-1 : 0] a, b;
	reg [OUT_BITS-1 : 0] prod;

	assign a = 8'h12;
	assign b = 8'h34;

	// instantiate modules
	multiplier #(.IN_BITS(IN_BITS), .OUT_BITS(OUT_BITS))
		mult(.in_clk(clock), .in_rst(~key[0]),
			.in_a(a), .in_b(b),
			.in_start(~key[1]),
			.out_finished(ledr[0]),
			.out_prod(prod));

	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg0(.in_digit(prod[3:0]), .out_leds(hex0));
	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg1(.in_digit(prod[7:4]), .out_leds(hex1));
	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg2(.in_digit(prod[11:8]), .out_leds(hex2));
	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg3(.in_digit(prod[15:12]), .out_leds(hex3));

endmodule
