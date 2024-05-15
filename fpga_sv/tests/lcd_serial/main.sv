/**
 * serial lcd
 * @author Tobias Weber
 * @date 9-may-2024
 * @license see 'LICENSE' file
 */

module lcd_serial
(
	// main clock
	input clk27,

	// lcd
	output serlcd_ena,
	output serlcd_sel,
	output serlcd_cmd,
	output serlcd_clk,
	output serlcd_out,

	// keys and leds
	input [1:0] key,
	output [5:0] led
);


localparam MAIN_CLK      = 27_000_000;
localparam SERIAL_CLK    = 10_000_000;

localparam SCREEN_WIDTH  = 240;
localparam SCREEN_HEIGHT = 135;
localparam SCREEN_HOFFS  = 40;
localparam SCREEN_VOFFS  = 55;
localparam PIXEL_BITS    = 16;

localparam TILE_WIDTH    = 12;
localparam TILE_HEIGHT   = 20;

localparam TEXT_ROWS     = SCREEN_HEIGHT / TILE_HEIGHT;
localparam TEXT_COLS     = SCREEN_WIDTH / TILE_WIDTH;

localparam FIRST_CHAR    = 32;

localparam SCREEN_WIDTH_BITS  = $clog2(SCREEN_WIDTH);
localparam SCREEN_HEIGHT_BITS = $clog2(SCREEN_HEIGHT);
localparam TILE_WIDTH_BITS    = $clog2(TILE_WIDTH);
localparam TILE_HEIGHT_BITS   = $clog2(TILE_HEIGHT);
localparam TILE_X_BITS        = $clog2(SCREEN_WIDTH / TILE_WIDTH);
localparam TILE_Y_BITS        = $clog2(SCREEN_HEIGHT / TILE_HEIGHT);
localparam TILE_NUM_BITS      = $clog2((SCREEN_WIDTH / TILE_WIDTH) * (SCREEN_HEIGHT / TILE_HEIGHT));


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst, show_tp;
wire update = 1'b1;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(show_tp));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// lcd interface
// ----------------------------------------------------------------------------
logic lcd_rst, lcd_sel;
logic [SCREEN_WIDTH_BITS - 1 : 0] pixel_x;
logic [SCREEN_HEIGHT_BITS - 1 : 0] pixel_y;
logic [PIXEL_BITS - 1 : 0] cur_pixel_col;

assign serlcd_ena = ~lcd_rst;
assign serlcd_sel = ~lcd_sel;

video_serial #(.SERIAL_BITS(8), .PIXEL_BITS(PIXEL_BITS),
	.SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
	.SCREEN_HOFFS(SCREEN_HOFFS), .SCREEN_VOFFS(SCREEN_VOFFS),
	.SCREEN_HINV(1'b1), .SCREEN_VINV(1'b0),
	.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(SERIAL_CLK))
lcd_mod (.in_clk(clk27), .in_rst(rst),
	.in_pixel(cur_pixel_col), .in_testpattern(show_tp), .in_update(update),
	.out_vid_rst(lcd_rst), .out_vid_select(lcd_sel), .out_vid_cmd(serlcd_cmd),
	.out_vid_serial_clk(serlcd_clk), .out_vid_serial(serlcd_out),
	.out_hpix(pixel_x), .out_vpix(pixel_y));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// text interface
// ----------------------------------------------------------------------------
logic [TILE_X_BITS - 1 : 0] tile_x;
logic [TILE_Y_BITS - 1 : 0] tile_y;
logic [TILE_NUM_BITS - 1 : 0] tile_num;
logic [TILE_WIDTH_BITS - 1 : 0] tile_pix_x;
logic [TILE_HEIGHT_BITS - 1 : 0] tile_pix_y;
logic font_pixel;

tile #(.SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
	.TILE_WIDTH(TILE_WIDTH), .TILE_HEIGHT(TILE_HEIGHT))
tile_mod (.in_x(pixel_x), .in_y(pixel_y),
	.out_tile_x(tile_x), .out_tile_y(tile_y), .out_tile_num(tile_num),
	.out_tile_pix_x(tile_pix_x), .out_tile_pix_y(tile_pix_y));

logic [7 : 0] cur_char; //= 8'h31;
logic [6 : 0] cur_char_idx = tile_num < TEXT_ROWS*TEXT_COLS
	? 7'(cur_char - FIRST_CHAR)
	: 7'(8'h20 - FIRST_CHAR);

// font rom; generate with:
//   ./genfont -h 20 -w 24 --target_height 20 --target_pitch 2 --target_left 1 --pitch_bits 6 -t sv -o font.sv
font font_rom(.in_char(cur_char_idx),
	.in_x(tile_pix_x), .in_y(tile_pix_y),
	.out_pixel(font_pixel));

// set current pixel colour
assign cur_pixel_col = font_pixel==1'b1 ? {PIXEL_BITS{1'b1}} : {PIXEL_BITS{1'b0}};

// text buffer in rom; generate with:
//   ./genrom -l 20 -t sv -p 1 -d 1 -f 0 -m textmem 0.txt -o textmem.sv
textmem text_mem(.in_addr(tile_num), .out_data(cur_char));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// output test clock
// ----------------------------------------------------------------------------
logic test_clk;
assign led[0] = ~test_clk;
assign led[1] = ~rst;
assign led[2] = ~show_tp;
assign led[5:3] = 3'b111;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(1))
clk_test (.in_clk(clk27), .in_rst(rst), .out_clk(test_clk));
// ----------------------------------------------------------------------------


endmodule
