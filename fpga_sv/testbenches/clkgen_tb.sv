/**
 * clkgen testbench
 * @author Tobias Weber
 * @date 14-july-2024
 * @license see 'LICENSE' file
 *
 * iverilog -D __IN_SIMULATION__ -g2012 -o clkgen_tb ../lib/clock/clkgen.sv clkgen_tb.sv
 * ./clkgen_tb
 * gtkwave clkgen_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ms / 1us

module clkgen_tb;
	localparam ITERS    = 64;

	localparam MAIN_CLK = 500;
	localparam SLOW_CLK = 100;

	logic clk = 1'b1, rst = 1'b0;


	// --------------------------------------------------------------------
	// instantiate clock generator
	logic slow_clk;

	clkgen #(
		.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK),
		.CLK_INIT(1'b1)
	)
	serial_clk_mod
	(
		.in_clk(clk), .in_rst(rst),
		.out_clk(slow_clk)
	);
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// run simulation
	integer iter, clk_ticks;

	initial begin
		$dumpfile("clkgen_tb.vcd");
		$dumpvars(0, clkgen_tb);

		iter = 0;
		clk_ticks = 0;
	end


	always #1 begin  // every ms
		if(iter > ITERS) begin
			$dumpflush();
			$finish();
		end else begin
			clk = ~clk;
			if(clk == 1'b1)
				++clk_ticks;
			++iter;
		end
	end


	always@(posedge clk) begin
		$display("MAIN CLOCK: tick: %4d, time: %8t us", clk_ticks, $realtime);
	end


	always@(posedge slow_clk) begin
		$display("SLOW CLOCK: tick: %4d, time: %8t us\n", clk_ticks, $realtime);
	end
	// --------------------------------------------------------------------

endmodule
