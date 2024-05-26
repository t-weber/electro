/**
 * serial lcd
 * @author Tobias Weber
 * @date 9-may-2024
 * @license see 'LICENSE' file
 */


// use text buffer in rom (or alternatively ram)
`define USE_TEXTROM


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


localparam MAIN_CLK           = 27_000_000;
localparam SERIAL_CLK         = 10_000_000;

localparam SCREEN_WIDTH       = 240;
localparam SCREEN_HEIGHT      = 135;
localparam SCREEN_HOFFS       = 40;
localparam SCREEN_VOFFS       = 52;
localparam RED_BITS           = 5;
localparam GREEN_BITS         = 6;
localparam BLUE_BITS          = 5;
localparam PIXEL_BITS         = RED_BITS + GREEN_BITS + BLUE_BITS;

localparam TILE_WIDTH         = 12;
localparam TILE_HEIGHT        = 20;

localparam TEXT_ROWS          = SCREEN_HEIGHT / TILE_HEIGHT;
localparam TEXT_COLS          = SCREEN_WIDTH / TILE_WIDTH;

localparam USE_COLOUR_MEM     = 1;

localparam SCREEN_WIDTH_BITS  = $clog2(SCREEN_WIDTH);
localparam SCREEN_HEIGHT_BITS = $clog2(SCREEN_HEIGHT);
localparam TILE_WIDTH_BITS    = $clog2(TILE_WIDTH);
localparam TILE_HEIGHT_BITS   = $clog2(TILE_HEIGHT);
localparam TILE_X_BITS        = $clog2(SCREEN_WIDTH / TILE_WIDTH);
localparam TILE_Y_BITS        = $clog2(SCREEN_HEIGHT / TILE_HEIGHT);
localparam TILE_NUM_BITS      = $clog2(TEXT_COLS * TEXT_ROWS)
                                + 1 /* because of the additional half-line at the bottom */;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
logic rst, show_tp;
logic update = 1'b1;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(show_tp), .out_debounced());
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
logic slow_clk;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(1))
clk_test (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
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
	.RED_BITS(RED_BITS), .GREEN_BITS(GREEN_BITS), .BLUE_BITS(BLUE_BITS),
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
	.TILE_WIDTH(TILE_WIDTH), .TILE_HEIGHT(TILE_HEIGHT),
	.TILE_X_BITS(TILE_X_BITS), .TILE_Y_BITS(TILE_Y_BITS), .TILE_NUM_BITS(TILE_NUM_BITS))
tile_mod (.in_x(pixel_x), .in_y(pixel_y),
	.out_tile_x(tile_x), .out_tile_y(tile_y), .out_tile_num(tile_num),
	.out_tile_pix_x(tile_pix_x), .out_tile_pix_y(tile_pix_y));

logic [7 : 0] cur_char; //= 8'h31;
logic [6 : 0] cur_char_chk;
assign cur_char_chk = tile_num < TEXT_ROWS*TEXT_COLS
	? $size(cur_char_chk)'(cur_char)
	: $size(cur_char_chk)'(8'h20);

// font rom; generate with:
//   ./genfont -h 20 -w 24 --target_height 20 --target_pitch 2 --target_left 1 --pitch_bits 6 -t sv -o font.sv
font font_rom(.in_char(cur_char_chk),
	.in_x(tile_pix_x), .in_y(tile_pix_y),
	.out_pixel(font_pixel), .out_line());


`ifdef USE_TEXTROM
	// text buffer as rom; generate with:
	//   ./genrom -l 20 -t sv -p 1 -d 1 -f 0 -m textmem 0.txt -o textmem.sv
	textmem #(.ADDR_BITS(TILE_NUM_BITS))
	textmem_mod (.in_addr(tile_num), .out_data(cur_char));
`else
	logic [TILE_NUM_BITS - 1 : 0] tile_num_write = 0;
	logic write_textmem = 1'b1;
	logic [7 : 0] char_write = 8'd42;

	// text buffer as ram
	ram_2port #(.ADDR_BITS(TILE_NUM_BITS), .WORD_BITS(8),
		.NUM_WORDS(TEXT_COLS * TEXT_ROWS), .ALL_WRITE(1'b0))
	textmem_mod (.in_clk(clk27), .in_rst(rst),
		// port 1
		.in_read_ena_1(1'b0), .in_write_ena_1(write_textmem),
		.in_addr_1(tile_num_write), .in_data_1(char_write), .out_data_1(),
		// port 2
		.in_read_ena_2(1'b1), .in_write_ena_2(1'b0),
		.in_addr_2(tile_num), .in_data_2(8'b0), .out_data_2(cur_char));

	/*ram_1port #(.ADDR_BITS(TILE_NUM_BITS), .WORD_BITS(8), .NUM_WORDS(TEXT_COLS * TEXT_ROWS))
	textmem_mod (.in_clk(clk27), .in_rst(rst),
		.in_read_ena(1'b1), .in_write_ena(write_textmem),
		.in_addr_read(tile_num), .out_data_read(cur_char),
		.in_addr_write(tile_num_write), .in_data_write(char_write));*/

	// slowly write some letters as test
	always_ff@(posedge slow_clk, posedge rst) begin
		if(rst == 1'b1) begin
			tile_num_write <= $size(tile_num_write)'(1'b0);
		end else begin
			if(tile_num_write < TEXT_COLS * TEXT_ROWS)
				tile_num_write <= $size(tile_num_write)'(tile_num_write + 1'b1);
			else
				tile_num_write <= $size(tile_num_write)'(1'b0);
		end
	end

	//always_comb begin
	//	write_textmem = 1'b1;
	//	char_write = 8'(8'd32 + tile_num_write);
	//end
`endif


generate
if(USE_COLOUR_MEM == 1'b0) begin
	// set current pixel colour to a fixed value
	assign cur_pixel_col = font_pixel==1'b1
		? { {RED_BITS{1'b1}}, {GREEN_BITS{1'b1}}, {BLUE_BITS{1'b1}}}   // foreground
		: { {RED_BITS{1'b0}}, {GREEN_BITS{1'b0}}, {BLUE_BITS{1'b1}}};  // background
end else begin
	logic [PIXEL_BITS - 1 : 0] cur_pixel_col_fg, cur_pixel_col_bg;

	// set pixel colour using memories
	assign cur_pixel_col = font_pixel==1'b1 ? cur_pixel_col_fg : cur_pixel_col_bg;

	// set pixel foreground colour from a memory
	textmem_fgcol #(.ADDR_BITS(TILE_NUM_BITS))
	textmem_fgcol_mod (.in_addr(tile_num), .out_data(cur_pixel_col_fg));

	// set pixel background colour from a memory
	textmem_bgcol #(.ADDR_BITS(TILE_NUM_BITS))
	textmem_bgcol_mod (.in_addr(tile_num), .out_data(cur_pixel_col_bg));
end
endgenerate
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// leds
// ----------------------------------------------------------------------------
assign led[0] = ~slow_clk;
assign led[1] = ~rst;
assign led[2] = ~show_tp;
assign led[5:3] = 3'b111;
// ----------------------------------------------------------------------------


endmodule
