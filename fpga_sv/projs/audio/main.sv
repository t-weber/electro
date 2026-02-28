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
	input wire clk27,

	// keys and leds
	input  wire [1:0] key,
	output wire [5:0] led,

	// audio
	output wire aud_ena,
	output wire aud_dat,
	output wire aud_lrclk,
	output wire aud_bitclk
);


localparam MAIN_CLK    = 27_000_000;

localparam FRAME_BITS  = 32;
localparam FREQ_BITS   = 16;
localparam SAMPLE_BITS = 16;
localparam SAMPLE_FREQ = 44_100;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
logic rst;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(key[1]), .out_debounced(rst));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// clocks
// sample_clk = sample_freq
// bit_clk    = sample_freq * sample_bits * 2 channels
// ----------------------------------------------------------------------------
logic sample_clk, bit_clk;

clkpulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SAMPLE_FREQ))
sample_clk_mod (.in_clk(clk27), .in_rst(rst), .out_clk(sample_clk), .out_re());

clkpulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SAMPLE_FREQ * SAMPLE_BITS * 2))
bit_clk_mod (.in_clk(clk27), .in_rst(rst), .out_clk(bit_clk), .out_re());
// ----------------------------------------------------------------------------


//------------------------------------------------------------------------------
// tones
//------------------------------------------------------------------------------
logic [FREQ_BITS - 1 : 0] tone_hz;
logic [7 : 0] tone_cycle;
logic tone_finished, samples_end;
logic audio_active = 1'b1;
logic amp;

/**
 * tone generation
 */
audio #(.TONE_BITS(FREQ_BITS), .FRAME_BITS(FRAME_BITS),
	.SAMPLE_BITS(SAMPLE_BITS), .SAMPLE_FREQ(SAMPLE_FREQ))
audio_mod(.in_reset(rst), .in_bitclk(bit_clk), .in_sampleclk(sample_clk),
	.in_tone_hz(tone_hz), .out_data(amp), .out_samples_end(samples_end));

/**
 * tone sequence
 */
tones #(.MAIN_HZ(SAMPLE_FREQ), .FREQ_BITS(FREQ_BITS))
tones_mod(.in_clk(sample_clk), .in_reset(rst),
	.in_enable(audio_active), .out_freq(tone_hz),
	.out_cycle(tone_cycle), .out_finished(tone_finished));
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// audio
//------------------------------------------------------------------------------
assign aud_ena = 1'b1;
assign aud_dat = amp;
assign aud_bitclk = bit_clk;
assign aud_lrclk = sample_clk;
//------------------------------------------------------------------------------


//------------------------------------------------------------------------------
// debugging
//------------------------------------------------------------------------------
//assign led = ~tone_cycle[5 : 0];
assign led = ~tone_hz[5 : 0];
//assign led[0] = ~amp;
//------------------------------------------------------------------------------

endmodule
