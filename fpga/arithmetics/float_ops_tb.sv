//
// floating point operations testbench
// @author Tobias Weber <tobias.weber@tum.de>
// @date 10-June-2023
// @license see 'LICENSE' file
//
// iverilog -g2012 -o float_ops_tb float_ops.sv float_ops_tb.sv
// ./float_ops_tb
//


`timescale 1ms / 1us

module float_ops_tb;

	localparam BITS = 32;
	localparam EXP_BITS = 8;
	//localparam BITS = 16;
	//localparam EXP_BITS = 5;

	localparam MAX_ITER = 64;

	reg clk = 0, rst = 0;
	reg ready;

	logic [BITS-1 : 0] a, b;
	logic [BITS-1 : 0] result;
	logic [1 : 0] op = 2'b00;
	integer iter;


	// instantiate modules
	float_ops #(.BITS(BITS), .EXP_BITS(EXP_BITS))
		mult(.in_clk(clk), .in_rst(rst),
			.in_op(op),
			.in_a(a), .in_b(b), .in_start(1'b1),
			.out_ready(ready), .out_result(result));


	// run simulation
	initial begin
		clk <= 0;

		//a <= 32'hbf000000;   // -0.5
		//b <= 32'h3e800000;   // +0.25
		// expected result: -0.125 = 0xbe000000

		//a <= 16'h5640;   // +100
		//b <= 16'hcc00;   // -0.25

		a <= 32'hbf9d70a3;   // -1.23
		b <= 32'h4015c28f;   // +2.34
		// expected results:
		//	- mul: -2.8782  = 0xc038346d,
		//	- div: -0.52564 = 0xbf069069
		//	- add:  1.11    = 0x3f8e147a
		//	- sub: -3.57    = 0xc0647ae1

		// multiplication test
		rst <= 1; #10;
		op <= 2'b00;
		for(iter = 0; iter < MAX_ITER; ++iter) begin
			clk <= !clk;
			rst <= 0;

			#10;
			$display("iter = %0d: t = %0t, clk = %b, ready = %b, %h * %h = %h, exp = %h, mant = %h",
				iter, $time, clk, ready, a, b, result,
				result[BITS-2 : BITS-1-EXP_BITS], result[BITS-2-EXP_BITS : 0]);

			if(ready) begin
				#10; clk <= !clk;
				iter = MAX_ITER;
			end
		end

		// division test
		rst <= 1; #10;
		op <= 2'b01;
		$display("");
		for(iter = 0; iter < MAX_ITER; ++iter) begin
			clk <= !clk;
			rst <= 0;

			#10;
			$display("iter = %0d: t = %0t, clk = %b, ready = %b, %h / %h = %h, exp = %h, mant = %h",
				iter, $time, clk, ready, a, b, result,
				result[BITS-2 : BITS-1-EXP_BITS], result[BITS-2-EXP_BITS : 0]);

			if(ready) begin
				#10; clk <= !clk;
				iter = MAX_ITER;
			end
		end

		// addition test
		rst <= 1; #10;
		op <= 2'b10;
		$display("");
		for(iter = 0; iter < MAX_ITER; ++iter) begin
			clk <= !clk;
			rst <= 0;

			#10;
			$display("iter = %0d: t = %0t, clk = %b, ready = %b, %h + %h = %h, exp = %h, mant = %h",
				iter, $time, clk, ready, a, b, result,
				result[BITS-2 : BITS-1-EXP_BITS], result[BITS-2-EXP_BITS : 0]);

			if(ready) begin
				#10; clk <= !clk;
				iter = MAX_ITER;
			end
		end

		// subtraction test
		rst <= 1; #10;
		op <= 2'b11;
		$display("");
		for(iter = 0; iter < MAX_ITER; ++iter) begin
			clk <= !clk;
			rst <= 0;

			#10;
			$display("iter = %0d: t = %0t, clk = %b, ready = %b, %h - %h = %h, exp = %h, mant = %h",
				iter, $time, clk, ready, a, b, result,
				result[BITS-2 : BITS-1-EXP_BITS], result[BITS-2-EXP_BITS : 0]);

			if(ready) begin
				#10; clk <= !clk;
				iter = MAX_ITER;
			end
		end
end

endmodule
