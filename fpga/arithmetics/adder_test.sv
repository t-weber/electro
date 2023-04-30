/**
 * adder test
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 30-April-2023
 * @license see 'LICENSE' file
 *
 * Reference: https://en.wikipedia.org/wiki/Adder_(electronics)
 */

module adder_test(
	output [6 : 0] hex0, hex1, hex2, hex3
);

	localparam BITS = 16;

	logic [BITS-1 : 0] a, b;
	logic [BITS-1 : 0] sum;
	
	assign a = 16'h1234;
	assign b = 16'h2345;
	
	ripplecarryadder #(.BITS(BITS)) cnt(.in_a(a), .in_b(b), .out_sum(sum));

	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1)) seg0(.in_digit(sum[3:0]), .out_leds(hex0));
	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1)) seg1(.in_digit(sum[7:4]), .out_leds(hex1));
	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1)) seg2(.in_digit(sum[11:8]), .out_leds(hex2));
	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1)) seg3(.in_digit(sum[15:12]), .out_leds(hex3));
endmodule
