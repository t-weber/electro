/**
 * lfsr testbench
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 29-july-2024
 * @license see 'LICENSE' file
 *
 * iverilog -D __IN_SIMULATION__ -g2012 -o lfsr_tb ../lib/lfsr.sv lfsr_tb.sv
 * ./lfsr_tb
 * gtkwave lfsr_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ms / 1us

module lfsr_tb;
	localparam BITS  = 8;
	localparam ITERS = 64;

	logic clk = 1'b1;


	// --------------------------------------------------------------------
	// instantiate lfsr
	wire [BITS] rnd_val;

	lfsr #(.BITS(BITS), .SEED(8'b0000_0101))
	lfsr_mod (
		.in_clk(clk), .in_rst(1'b0),
		.in_seed(8'b0000_0101),
		.in_setseed(1'b0), .in_nextval(1'b1),
		.out_val(rnd_val)
	);
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// run simulation
	integer iter, clk_ticks;

	initial begin
		$dumpfile("lfsr_tb.vcd");
		$dumpvars(0, lfsr_tb);

		iter = 0;
	end


	always #1 begin  // every ms
		if(iter > ITERS) begin
			$dumpflush();
			$finish();
		end else begin
			clk = ~clk;
			++iter;
		end
	end


	always@(posedge clk) begin
		$display("t = %8t us, val = %x", $realtime, rnd_val);
	end
	// --------------------------------------------------------------------

endmodule
