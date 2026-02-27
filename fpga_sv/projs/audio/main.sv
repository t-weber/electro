/**
 * timed sequence of tones
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 26-feb-2026
 * @license see 'LICENSE' file
 */


//`default_nettype /*wire*/ none


module main
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	output [5:0] led
);


localparam MAIN_CLK   = 27_000_000;
localparam SAMPLE_CLK = 25;

localparam FREQ_BITS  = 16;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(key[1]), .out_debounced(rst));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// clocks
// ----------------------------------------------------------------------------
wire sample_clk;

clkpulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SAMPLE_CLK))
sample_clk_mod (.in_clk(clk27), .in_rst(rst), .out_clk(sample_clk), .out_re());
// ----------------------------------------------------------------------------


//------------------------------------------------------------------------------
// tones
//------------------------------------------------------------------------------
logic [FREQ_BITS - 1 : 0] tone_hz;
logic [7 : 0] tone_cycle;
logic tone_finished;
logic audio_active = 1'b1;

/**
 * tone generation
 */
// TODO


/**
 * tone sequence
 */
tones #(.MAIN_HZ(SAMPLE_CLK), .FREQ_BITS(FREQ_BITS))
tones_mod(.in_clk(sample_clk), .in_reset(rst),
	.in_enable(audio_active), .out_freq(tone_hz),
	.out_cycle(tone_cycle), .out_finished(tone_finished));
//------------------------------------------------------------------------------



//------------------------------------------------------------------------------
// debugging
//------------------------------------------------------------------------------
assign led = ~tone_hz[5 : 0];
//assign led = ~tone_cycle[5 : 0];
//------------------------------------------------------------------------------

endmodule
