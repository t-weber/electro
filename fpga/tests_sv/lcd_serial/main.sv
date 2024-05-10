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
localparam SCREEN_VOFFS  = 53;


wire rst = ~key[0];
wire update = 1'b1;

logic lcd_rst, lcd_sel;

assign serlcd_ena = ~lcd_rst;
assign serlcd_sel = ~lcd_sel;


video_serial #(.SERIAL_BITS(8), .PIXEL_BITS(16),
	.SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
	.SCREEN_HOFFS(SCREEN_HOFFS), .SCREEN_VOFFS(SCREEN_VOFFS),
	.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(SERIAL_CLK))
lcd_mod (.in_clk(clk27), .in_rst(rst),
	.in_pixel(16'b11111_000000_00000), .in_testpattern(1'b0), .in_update(update),
	.out_vid_rst(lcd_rst), .out_vid_select(lcd_sel), .out_vid_cmd(serlcd_cmd),
	.out_vid_serial_clk(serlcd_clk), .out_vid_serial(serlcd_out));


// output test clock
logic test_clk;
assign led[0] = ~test_clk;
assign led[5:1] = 5'b11111;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(1))
clk_test (.in_clk(clk27), .in_rst(rst), .out_clk(test_clk));


endmodule
