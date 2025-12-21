/**
 * pulsegen testbench
 * @author Tobias Weber
 * @date 14-july-2024
 * @license see 'LICENSE' file
 *
 * iverilog -D __IN_SIMULATION__ -g2012 -o pulsegen_tb ../lib/clock/pulsegen.sv ../lib/clock/clkgen.sv pulsegen_tb.sv
 * ./pulsegen_tb
 * gtkwave pulsegen_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1us / 100ns          // clock period: 2us
`default_nettype /*wire*/ none  // no implicit declarations


module pulsegen_tb;


// clock and reset
localparam longint MAIN_CLK     = 500_000;
localparam longint SLOW_CLK     = 100_000;
localparam int     MAX_CLK_ITER = 50;
localparam int     RESET_ITERS  = 4;

logic clk = 1'b1, rst = 1'b0;
always #1 clk = ~clk;


// --------------------------------------------------------------------
// instantiate slow clock generator
// --------------------------------------------------------------------
logic slow_clk;

clkgen #(
	.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK),
	.CLK_INIT(1'b1)
)
slow_clk_mod
(
	.in_clk(clk), .in_rst(rst),
	.out_clk(slow_clk)
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// instantiate slow pulse generator
// --------------------------------------------------------------------
logic pulse_re, pulse_fe;

pulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
slow_pulsegen_mod
(
	.in_clk(clk), .in_rst(rst),
	.out_pulse_re(pulse_re),
	.out_pulse_fe(pulse_fe)
);
// --------------------------------------------------------------------


//---------------------------------------------------------------------------
// run simulation
//---------------------------------------------------------------------------
initial begin
	$dumpfile("pulsegen_tb.vcd");
	$dumpvars(0, pulsegen_tb);

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
