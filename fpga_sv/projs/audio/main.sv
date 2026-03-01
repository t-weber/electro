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
	output wire aud_bitclk,

	// text lcd
	inout txtlcd_scl,
	inout txtlcd_sda
);


localparam MAIN_CLK        = 27_000_000;
localparam SERIAL_CLK_LCD  =  1_000_000;

localparam SERIAL_BITS_LCD = 8;

// audio
localparam FRAME_BITS      = 16;
localparam FREQ_BITS       = 16;
localparam SAMPLE_BITS     = 16;
localparam SAMPLE_FREQ     = 44_100;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
logic rst;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(key[1]), .out_debounced(rst));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// audio clocks
// sample_clk = sample_freq
// bit_clk    = sample_freq * sample_bits * 2 channels
// ----------------------------------------------------------------------------
logic bit_clk, sample_clk;

clkpulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SAMPLE_FREQ * SAMPLE_BITS * 2))
bit_clk_mod (.in_clk(clk27), .in_rst(rst), .out_clk(bit_clk), .out_re());

//clkpulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SAMPLE_FREQ))
//sample_clk_mod (.in_clk(clk27), .in_rst(rst), .out_clk(sample_clk), .out_re());

clkctr #(.USE_RISING_EDGE(0), .COUNTER(FRAME_BITS), .CLK_INIT(0))
sample_clk_mod(.in_clk(bit_clk), .in_reset(rst), .out_clk(sample_clk));
// ----------------------------------------------------------------------------


//------------------------------------------------------------------------------
// tones
//------------------------------------------------------------------------------
localparam TONE_CYCLE_BITS = 6; //$clog2(tones.NUM_TONES);

logic [FREQ_BITS - 1 : 0] tone_hz;
logic [TONE_CYCLE_BITS - 1 : 0] tone_cycle;
logic tones_finished, samples_end;
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
tones #(.MAIN_HZ(SAMPLE_FREQ), .FREQ_BITS(FREQ_BITS), .CYCLE_BITS(TONE_CYCLE_BITS))
tones_mod(.in_clk(sample_clk), .in_reset(rst),
	.in_enable(audio_active), .out_freq(tone_hz),
	.out_cycle(tone_cycle), .out_finished(tones_finished));
//------------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// bcd conversion
// ----------------------------------------------------------------------------
logic tone_cycle_bcd_finished;
logic [2*4 - 1 : 0] tone_cycle_bcd;

bcd #(.IN_BITS(TONE_CYCLE_BITS), .OUT_BITS(2*4), .NUM_BCD_DIGITS(2))
bcd_tone_cycle_mod(.in_clk(clk27), .in_rst(rst),
	.in_num(tone_cycle + 1'b1), .out_bcd(tone_cycle_bcd),
	.in_start(1'b1), .out_finished(tone_cycle_bcd_finished));
// ----------------------------------------------------------------------------


// --------------------------------------------------------------------
// text lcd serial bus
// --------------------------------------------------------------------
wire lcd_serial_enable, lcd_serial_ready, lcd_serial_error;
wire [SERIAL_BITS_LCD - 1 : 0] lcd_serial_data, lcd_serial_data_in;
wire lcd_serial_next_word;

// instantiate serial module
serial_2wire #(
	.BITS(SERIAL_BITS_LCD), .ADDR_BITS(SERIAL_BITS_LCD),
	.LOWBIT_FIRST(0), .TRANSMIT_ADDR(1),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK_LCD),
	.IGNORE_ERROR(1'b0)
)
serial_lcd_mod(
	.in_clk(clk27), .in_rst(rst), .out_err(lcd_serial_error),
	.in_enable(lcd_serial_enable), .in_write(1'b1), .out_ready(lcd_serial_ready),
	//.in_addr_write(8'h26), .in_addr_read(8'h27),
	.in_addr_write(8'h4e), .in_addr_read(8'h4f),
	.inout_serial_clk(txtlcd_scl), .inout_serial(txtlcd_sda),
	.in_parallel(lcd_serial_data), //.out_parallel(lcd_serial_data_in),
	.out_next_word(lcd_serial_next_word)
);
// --------------------------------------------------------------------


// ----------------------------------------------------------------------------
// text lcd serial interface
// ----------------------------------------------------------------------------
localparam LCD_LINE0 =  0;
localparam LCD_LINE1 = 40;
localparam LCD_LINE2 = 20;
localparam LCD_LINE3 = 60;

localparam LCD_NUM_LINES = 4;
localparam LCD_NUM_ROWS  = 20;

wire lcd_update;
wire [SERIAL_BITS_LCD - 1 : 0] lcd_char_ctr;
assign lcd_update = tone_cycle_bcd_finished;
assign lcd_serial_data_in =
	lcd_char_ctr == LCD_LINE0 + 0 ? "T" :
	lcd_char_ctr == LCD_LINE0 + 1 ? "o" :
	lcd_char_ctr == LCD_LINE0 + 2 ? "n" :
	lcd_char_ctr == LCD_LINE0 + 3 ? "e" :
	lcd_char_ctr == LCD_LINE0 + 4 ? ":" :
	lcd_char_ctr == LCD_LINE0 + 6 ? 8'h30 + tone_cycle_bcd[2*4 - 1 : 1*4] :
	lcd_char_ctr == LCD_LINE0 + 7 ? 8'h30 + tone_cycle_bcd[1*4 - 1 : 0*4] :
	lcd_char_ctr == LCD_LINE0 + 9 ? "/" :
	lcd_char_ctr == LCD_LINE0 + 11 ? "5" :
	lcd_char_ctr == LCD_LINE0 + 12 ? "7" :

	lcd_char_ctr == LCD_LINE1 + 0 ? (tones_finished ? "D" : "R") :
	lcd_char_ctr == LCD_LINE1 + 1 ? (tones_finished ? "o" : "u") :
	lcd_char_ctr == LCD_LINE1 + 2 ? (tones_finished ? "n" : "n") :
	lcd_char_ctr == LCD_LINE1 + 3 ? (tones_finished ? "e" : "n") :
	lcd_char_ctr == LCD_LINE1 + 4 ? (tones_finished ? " " : "i") :
	lcd_char_ctr == LCD_LINE1 + 5 ? (tones_finished ? " " : "n") :
	lcd_char_ctr == LCD_LINE1 + 6 ? (tones_finished ? " " : "g") :

	" ";

// instantiate lcd module
txtlcd2 #(
	.MAIN_CLK(MAIN_CLK), .LCD_SIZE(LCD_NUM_LINES * LCD_NUM_ROWS),
	.WAIT_UPDATE_MS(5)
)
lcd_mod(
	.in_clk(clk27), .in_rst(rst), .out_char_ctr(lcd_char_ctr),
	.in_update(lcd_update), .in_bus_data(lcd_serial_data_in),
	.in_bus_next(lcd_serial_next_word), .in_bus_ready(lcd_serial_ready),
	.out_bus_data(lcd_serial_data), .out_bus_enable(lcd_serial_enable)
);
// ----------------------------------------------------------------------------


//------------------------------------------------------------------------------
// audio output
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
