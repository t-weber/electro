/**
 * testing timing pulses
 * @author Tobias Weber
 * @date 14-dec-2025
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o pulses ../lib/clock/clkgen.sv pulses.sv
 * ./pulses
 * gtkwave pulses.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1us / 100ns          // clock period: 2us
`default_nettype /*wire*/ none  // no implicit declarations


module pulses;


// clock
localparam longint MAIN_CLK = 500_000;
localparam longint SLOW_CLK = 100_000;
localparam int MAX_CLK_ITER = 50;
logic clk = 1'b0;
always #1 clk = ~clk;

// reset
localparam int RESET_ITERS = 4;
logic rst = 1'b1;



//---------------------------------------------------------------------------
// instantiate slow clock generator
// ---------------------------------------------------------------------------
logic slow_clk;

clkgen #(
	.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK),
	.CLK_INIT(1'b1)//, .CLK_SHIFT(1'b1)
)
slow_clk_mod
(
	.in_clk(clk), .in_rst(rst),
	.out_clk(slow_clk)
);
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// wait counter for slow clock pulses
// ---------------------------------------------------------------------------
localparam longint WAIT_DELAY = MAIN_CLK / SLOW_CLK;


// rising edge of slow clock
logic[$clog2(WAIT_DELAY) : 0] wait_ctr_re = 1'b0;
logic pulse_re = 1'b0;

always_ff@(posedge clk, posedge rst) begin
	if(rst == 1'b1) begin
		wait_ctr_re <= 1'b0;
		pulse_re <= 1'b0;
	end else begin
		pulse_re <= 1'b0;
		if(wait_ctr_re == WAIT_DELAY - 2) begin
			pulse_re <= 1'b1;
			wait_ctr_re <= 1'b0;
		end else begin
			wait_ctr_re <= wait_ctr_re + 1'b1;
		end
	end
end


// falling edge of slow clock
logic fsm_state = 1'b0;
logic[$clog2(WAIT_DELAY) : 0] wait_ctr_fe = 1'b0;
logic pulse_fe = 1'b0;

always_ff@(posedge clk, posedge rst) begin
	if(rst == 1'b1) begin
		fsm_state <= 1'b0;
		wait_ctr_fe <= 1'b0;
		pulse_fe <= 1'b0;
	end else begin
		pulse_fe <= 1'b0;
		wait_ctr_fe <= wait_ctr_fe + 1'b1;
		if(fsm_state == 1'b0) begin
			// offset pulse start
			if(wait_ctr_fe == WAIT_DELAY/2 - 1) begin
				fsm_state <= 1'b1;
				wait_ctr_fe <= 1'b0;
			end
		end else begin
			// generate periodic pulse
			if(wait_ctr_fe == WAIT_DELAY - 2) begin
				pulse_fe <= 1'b1;
				wait_ctr_fe <= 1'b0;
			end
		end
	end
end
// ---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// debug output
//---------------------------------------------------------------------------
always@(/*posedge*/ clk) begin
	$display("t = %3t, ", $time,
		"rst = %b, ", rst,
		"clk = %b, ", clk,
		"slow_clk = %b, ", slow_clk,
		"wait_ctr_re = %d, ", wait_ctr_re,
		"pulse_re = %b, ", pulse_re,
		"wait_ctr_fe = %d, ", wait_ctr_fe,
		"pulse_fe = %b", pulse_fe
	);
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// run simulation
//---------------------------------------------------------------------------
initial begin
	$dumpfile("pulses.vcd");
	$dumpvars(0, pulses);

	rst = 1'b1;
	#(RESET_ITERS);
	rst = 1'b0;

	#(MAX_CLK_ITER);

	$dumpflush();
	$finish();
end
//---------------------------------------------------------------------------


endmodule
