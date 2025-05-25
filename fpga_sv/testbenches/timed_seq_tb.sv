/**
 * test for timed sequence
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-may-2025
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o timed_seq_tb timed_seq.sv timed_seq_tb.sv
 * ./timed_seq_tb
 * gtkwave timed_seq_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1us / 100ns
`default_nettype /*wire*/ none  // no implicit declarations


module timed_seq_tb;

localparam ITERS = 75;
localparam BITS  = 8;


// clock
logic theclk = 1'b1;
logic [BITS - 1 : 0] dat;


timed_seq #(.MAIN_HZ(1_000_000), .DATA_BITS(BITS))
timed_seq_mod(.in_clk(theclk), .in_rst(1'b0), .in_enable(1'b1),
	.out_data(dat));



//---------------------------------------------------------------------------
//-- debug output
//---------------------------------------------------------------------------
always@(posedge theclk) begin
	$display("t = %3t", $time,
		", clk = %b", theclk,
		", dat = 0x%h = 0b%b", dat, dat);
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// run simulation
//---------------------------------------------------------------------------
integer iter;

initial begin
	$dumpfile("timed_seq_tb.vcd");
	$dumpvars(0, timed_seq_tb);

	for(iter = 0; iter < ITERS; ++iter) begin
		#1;
		theclk = !theclk;
	end

	$dumpflush();
end
//---------------------------------------------------------------------------


endmodule
