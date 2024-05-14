//
// multiplier testbench
// @author Tobias Weber <tobias.weber@tum.de>
// @date 1-May-2023
// @license see 'LICENSE' file
//
// iverilog -g2012 -o multiplier_tb ../arithmetics/multiplier.sv ../arithmetics/adder.sv multiplier_tb.sv
// ./multiplier_tb
//


`timescale 1ms / 1us

module multiplier_tb;

	localparam IN_BITS = 8;
	localparam OUT_BITS = 16;

	reg clk = 0, rst = 0;
	reg start, finished;

	logic [IN_BITS-1 : 0] a, b;
	logic [OUT_BITS-1 : 0] prod;
	integer iter;


	// instantiate modules
	multiplier #(.IN_BITS(IN_BITS), .OUT_BITS(OUT_BITS))
		mult(.in_clk(clk), .in_rst(rst),
			.in_a(a), .in_b(b),
			.in_start(start),
			.out_finished(finished),
			.out_prod(prod));


	// run simulation
	initial begin
		clk <= 0;
		rst <= 1;
		start <= 1;

		a <= 8'd123;
		b <= 8'd234;

		#10;

		for(iter = 0; iter < 64; ++iter) begin
			clk <= !clk;
			rst <= 0;
			start <= 0;

			#10;
			$display("iter = %0d: t = %0t, clk = %b, finished = %b, %d * %d = %d",
				iter, $time, clk, finished, a, b, prod);
		end
	end

endmodule
