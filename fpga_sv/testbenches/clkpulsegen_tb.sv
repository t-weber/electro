/**
 * pulsegen testbench
 * @author Tobias Weber
 * @date 14-july-2024
 * @license see 'LICENSE' file
 *
 * iverilog -D __IN_SIMULATION__ -g2012 -o clkpulsegen_tb ../lib/clock/clkpulsegen.sv clkpulsegen_tb.sv
 * ./clkpulsegen_tb
 * gtkwave clkpulsegen_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1us / 100ns          // clock period: 2us
`default_nettype /*wire*/ none  // no implicit declarations


module clkpulsegen_tb;


// clock and reset
localparam longint MAIN_CLK     = 1000_000;
localparam longint SLOW_CLK     =  100_000;
localparam int     MAX_CLK_ITER = 50;
localparam int     RESET_ITERS  = 4;

logic clk = 1'b1, rst = 1'b0;
always #1 clk = ~clk;


// --------------------------------------------------------------------
// instantiate slow pulse generator
// --------------------------------------------------------------------
logic slow_clk, pulse_re, pulse_fe;

clkpulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK),
	.CLK_INIT(1))
slow_pulsegen_mod
(
	.in_clk(clk), .in_rst(rst),
	.out_clk(slow_clk),
	.out_re(pulse_re), .out_fe(pulse_fe)
);
// --------------------------------------------------------------------


//---------------------------------------------------------------------------
// run simulation
//---------------------------------------------------------------------------
initial begin
	$dumpfile("clkpulsegen_tb.vcd");
	$dumpvars(0, clkpulsegen_tb);

	// reset
	rst = 1'b1;
	#(RESET_ITERS);
	rst = 1'b0;

	// clock
	#(MAX_CLK_ITER);

	$dumpflush();
	$finish();
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// debug output
//---------------------------------------------------------------------------
always@(/*posedge*/ clk) begin
	$display("t = %3t, ", $time,
		"rst = %b, ", rst,
		"clk = %b, ", clk,
		"slow_clk = %b, ", slow_clk,
		"pulse_re = %b, ", pulse_re,
		"pulse_fe = %b", pulse_fe
	);
end
//---------------------------------------------------------------------------


endmodule
