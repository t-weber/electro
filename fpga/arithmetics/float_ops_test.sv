/**
 * floating point operations test
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 11-June-2023
 * @license see 'LICENSE' file
 */


module float_ops_test
(
	input wire clock,
	input wire [0 : 0] key,
	output wire [6 : 0] hex0, hex1, hex2, hex3,
	output wire [0 : 0] ledr
);

	localparam BITS = 16;
	localparam EXP_BITS = 5;

	wire [BITS-1 : 0] a, b;
	reg [BITS-1 : 0] prod;

	//assign a = BITS'('h3800);   // +0.5
	//assign b = BITS'('hb400);   // -0.25
	// expected result: -0.125 = 0xb000

	assign a = BITS'('h5640);   // +100
	assign b = BITS'('hcc00);   // -16
	// expected result: -1600 = 0xe640

	// instantiate modules
	float_ops #(.BITS(BITS), .EXP_BITS(EXP_BITS))
		ops(.in_clk(clock), .in_rst(~key[0]),
			.in_op(2'b00),
			.in_a(a), .in_b(b), .in_start(1),
			.out_ready(ledr[0]), .out_prod(prod));

	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg0(.in_digit(prod[3:0]), .out_leds(hex0));
	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg1(.in_digit(prod[7:4]), .out_leds(hex1));
	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg2(.in_digit(prod[11:8]), .out_leds(hex2));
	  sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
			seg3(.in_digit(prod[15:12]), .out_leds(hex3));

endmodule
