/**
 * clkgen_var testbench
 * @author Tobias Weber
 * @date 17-february-2026
 * @license see 'LICENSE' file
 *
 * iverilog -D __IN_SIMULATION__ -g2012 -o clkgen_var_tb ../lib/clock/clkgen_var.sv clkgen_var_tb.sv
 * ./clkgen_var_tb
 * gtkwave clkgen_var_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ms / 1us

module clkgen_var_tb;
	localparam ITERS    = 64;
	localparam MAIN_CLK = 500;
	localparam CLK_BITS = 16;

	logic [CLK_BITS - 1 : 0] slow_clk_hz;
	//assign slow_clk_hz  = 500;

	logic clk = 1'b1, rst = 1'b0;


	// --------------------------------------------------------------------
	// instantiate slow clock generator
	logic slow_clk;

	clkgen_var #(
		.MAIN_HZ(MAIN_CLK), .HZ_BITS(CLK_BITS)
	)
	slow_clk_mod
	(
		.in_clk(clk), .in_reset(rst),
		.in_clk_hz(slow_clk_hz), .in_clk_init(1'b1), .in_clk_shift(1'b1),
		.out_clk(slow_clk)
	);
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// instantiate inverted clock generator
	logic inv_clk;

	clkgen_var #(
		.MAIN_HZ(MAIN_CLK)
	)
	inv_clk_mod
	(
		.in_clk(clk), .in_reset(rst),
		.in_clk_hz(MAIN_CLK), .in_clk_init(1'b0), .in_clk_shift(1'b0),
		.out_clk(inv_clk)
	);
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// run simulation
	integer iter, clk_ticks;

	initial begin
		$dumpfile("clkgen_var_tb.vcd");
		$dumpvars(0, clkgen_var_tb);

		// reset values
		iter = 0;
		clk_ticks = 0;
		slow_clk_hz = 8'd100;

		// reset
		rst = 1'b1; #1;
		rst = 1'b0;
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
