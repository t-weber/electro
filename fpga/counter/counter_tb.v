//
// counter testbench
// @author Tobias Weber <tobias.weber@tum.de>
// @date 16-apr-2023
// @license see 'LICENSE' file
//
// iverilog -o counter_tb counter.v ../lib/sevenseg.v counter_tb.v
// ./counter_tb
// gtkwave counter_tb.vcd
//


`timescale 1ms / 1us


module counter_tb;

	reg clk = 0;
	reg rst = 0;
	wire [3:0] ctr;
	wire [6:0] hex;

	integer iter;

	// instantiate modules
	counter #(.num_ctrbits(4)) cnt(.in_rst(rst), .in_clk(clk), .out_ctr(ctr));
	sevenseg #(.zero_is_on(0), .inverse_numbering(0)) seg(.in_digit(ctr), .out_leds(hex));

	// run simulation
	initial begin
		$dumpfile("counter_tb.vcd");
		$dumpvars(0, counter_tb);

		clk <= 0;
		rst <= 1;

		#1.0;

		$display("init: t = %0t, clk = %b, ctr = %h, hex = %h", $time, clk, ctr, hex);

		for(iter = 0; iter < 32; iter = iter+1) begin
			clk <= !clk;
			rst <= 0;

			#1.0;

			$display("iter = %0d: t = %0t, clk = %b, ctr = %h, hex = %h",
				iter, $time, clk, ctr, hex);
		end
	end

endmodule
