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
	input wire [1 : 0] sw,
	output wire [6 : 0] hex0, hex1, hex2, hex3,
	output wire [0 : 0] ledr
);

	localparam BITS = 16;
	localparam EXP_BITS = 5;

	wire ready;
	wire [BITS-1 : 0] a, b;
	reg [BITS-1 : 0] result, result_saved;

	assign ledr[0] = ready;

	//assign a = BITS'('h3800);   // +0.5
	//assign b = BITS'('hb400);   // -0.25
	// expected result: -0.125 = 0xb000

	assign a = BITS'('h5640);   // +100
	assign b = BITS'('hcc00);   // -16
	// expected results: - op 0: *: -1600 = 0xe640
	//                   - op 1: /: -6.25 = 0xc640
	//                   - op 2: +: 84 = 0x5540
	//                   - op 3: -: 116 = 0x5740

	// instantiate modules
	float_ops #(.BITS(BITS), .EXP_BITS(EXP_BITS))
		ops(.in_clk(clock), .in_rst(~key[0]),
			.in_op(sw[1:0]), //.in_op(2'b00),
			.in_a(a), .in_b(b), .in_start(1),
			.out_ready(ready), .out_result(result));

	always@(posedge ready) begin
		if(ready)
			result_saved <= result;
	end

	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
		seg0(.in_digit(result_saved[3:0]), .out_leds(hex0));
	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
		seg1(.in_digit(result_saved[7:4]), .out_leds(hex1));
	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
		seg2(.in_digit(result_saved[11:8]), .out_leds(hex2));
	sevenseg #(.ZERO_IS_ON(1), .INVERSE_NUMBERING(1))
		seg3(.in_digit(result_saved[15:12]), .out_leds(hex3));

endmodule
