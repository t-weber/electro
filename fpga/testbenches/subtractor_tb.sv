//
// subtractor testbench
// @author Tobias Weber <tobias.weber@tum.de>
// @date 13-May-2023
// @license see 'LICENSE' file
//
// iverilog -g2012 -o subtractor_tb ../arithmetics/subtractor.sv subtractor_tb.sv
// ./subtractor_tb
//


`timescale 1ms / 1us

module subtractor_tb;

	localparam BITS = 16;

	logic [BITS-1 : 0] a, b;
	logic [BITS-1 : 0] diff;

	// instantiate modules
	rippleborrowsubtractor #(.BITS(BITS)) cnt(.in_a(a), .in_b(b), .out_diff(diff));

	// run simulation
	initial begin
		a <= 8'd234;
		b <= 8'd123;

		#10;
		$display("%d - %d = %d", a, b, diff);
	end

endmodule
