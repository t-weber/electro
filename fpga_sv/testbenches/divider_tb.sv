//
// divider testbench
// @author Tobias Weber <tobias.weber@tum.de>
// @date 7-January-2024
// @license see 'LICENSE' file
//
// iverilog -g2012 -o divider_tb ../arithmetics/divider.sv ../arithmetics/adder.sv divider_tb.sv
// ./divider_tb
//


`timescale 1ms / 1us

module divider_tb;

	localparam BITS = 16;

	reg clk = 0, rst = 0;
	reg start, finished;

	logic [BITS-1 : 0] a, b;
	logic [BITS-1 : 0] quotient, remainder;
	integer iter;


	// instantiate modules
	divider #(.BITS(BITS))
		div(.in_clk(clk), .in_rst(rst),
			.in_a(a), .in_b(b),
			.in_start(start),
			.out_finished(finished),
			.out_quot(quotient), .out_rem(remainder));


	// run simulation
	initial begin
		clk <= 0;
		rst <= 1;
		start <= 1;

		a <= 16'd500;
		b <= 16'd123;

		#10;

		for(iter = 0; iter < 64; ++iter) begin
			clk <= !clk;
			rst <= 0;
			start <= 0;

			#10;
			$display("iter = %0d: t = %0t, clk = %b, finished = %b, %d / %d = %d (rem %d)",
				iter, $time, clk, finished, a, b, quotient, remainder);
		end
	end

endmodule
