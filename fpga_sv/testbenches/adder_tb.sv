//
// adder testbench
// @author Tobias Weber <tobias.weber@tum.de>
// @date 30-April-2023
// @license see 'LICENSE' file
//
// iverilog -g2012 -o adder_tb ../arithmetics/adder.sv adder_tb.sv
// ./adder_tb
//


`timescale 1ms / 1us

module adder_tb;

	localparam BITS = 16;

	logic [BITS-1 : 0] a, b;
	logic [BITS-1 : 0] sum;

	// instantiate modules
	ripplecarryadder #(.BITS(BITS)) cnt(.in_a(a), .in_b(b), .out_sum(sum));

	// run simulation
	initial begin
		a <= 8'd123;          // +123
		b <= 8'd234;          // +234
		//b <= ~8'd234 + 8'd1;  // -234

		#10;
		$display("%d + %d = %d", a, b, sum);
		//$display("%d + %d = -%d", a, b, ~sum + 8'd1);
	end

endmodule
