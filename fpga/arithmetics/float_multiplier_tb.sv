//
// float multiplier testbench
// @author Tobias Weber <tobias.weber@tum.de>
// @date 10-June-2023
// @license see 'LICENSE' file
//
// iverilog -g2012 -o float_multiplier_tb float_multiplier.sv float_multiplier_tb.sv
// ./float_multiplier_tb
//


`timescale 1ms / 1us

module float_multiplier_tb;

	localparam BITS = 32;
	localparam EXP_BITS = 8;

	reg clk = 0, rst = 0;
	reg ready;

	logic [BITS-1 : 0] a, b;
	logic [BITS-1 : 0] prod;
	integer iter;


	// instantiate modules
	float_multiplier #(.BITS(BITS), .EXP_BITS(EXP_BITS))
		mult(.in_clk(clk), .in_rst(rst),
			.in_a(a), .in_b(b), .in_start(1'b1),
			.out_ready(ready), .out_prod(prod));


	// run simulation
	initial begin
		clk <= 0;
		rst <= 1;

		//a <= 32'hbf000000;   // -0.5
		//b <= 32'h3e800000;   // +0.25
		// expected result: -0.125 = 0xbe000000

		a <= 32'hbf9d70a3;   // -1.23
		b <= 32'h4015c28f;   // +2.34
		// expected result: -2.8782 = 0xc038346d

		for(iter = 0; iter < 16; ++iter) begin
			clk <= !clk;
			rst <= 0;

			#10;
			$display("iter = %0d: t = %0t, clk = %b, ready = %b, %h * %h = %h, exp = %h, mant = %h",
				iter, $time, clk, ready, a, b, prod,
				prod[BITS-2 : BITS-1-EXP_BITS], prod[BITS-2-EXP_BITS : 0]);
		end
	end

endmodule
