/**
 * clkctr testbench
 * @author Tobias Weber
 * @date 19-february-2026
 * @license see 'LICENSE' file
 *
 * iverilog -D __IN_SIMULATION__ -g2012 -o clkctr_tb ../lib/clock/clkctr.sv clkctr_tb.sv
 * ./clkctr_tb
 * gtkwave clkctr_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ms / 1us

module clkctr_tb;
	localparam ITERS = 64;

	logic clk = 1'b1, rst = 1'b0;


	// --------------------------------------------------------------------
	// instantiate slow clock generator
	logic slow_clk;

	clkctr #(
		.COUNTER(5), .USE_RISING_EDGE(1'b1), .CLK_INIT(1'b1)
	)
	slow_clk_mod
	(
		.in_clk(clk), .in_reset(rst),
		.out_clk(slow_clk)
	);
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// run simulation
	integer iter, clk_ticks;

	initial begin
		$dumpfile("clkctr_tb.vcd");
		$dumpvars(0, clkctr_tb);

		// reset values
		iter = 0;
		clk_ticks = 0;

		// reset
		$display("Resetting...");
		rst = 1'b1; #1;
		rst = 1'b0;
		$display("Resetted.");
	end


	always #1 begin  // every ms
		if(iter > ITERS) begin
			// simulation end
			$dumpflush();
			$finish();
		end else begin
			// clock tick
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
