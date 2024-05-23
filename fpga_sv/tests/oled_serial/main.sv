/**
 * oled display test
 * @author Tobias Weber
 * @date 20-may-2024
 * @license see 'LICENSE' file
 */

module oled
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	output [2:0] led,

	// red leds
	output [9:0] ledr,

	// oled
	inout oled_scl,
	inout oled_sda
);


localparam MAIN_CLK      = 27_000_000;
localparam SERIAL_CLK    =    400_000;
localparam SLOW_CLK      =          1;

localparam SCREEN_WIDTH  = 128;
localparam SCREEN_HEIGHT = 64;
localparam SCREEN_PAGES  = SCREEN_HEIGHT / 8;

// tile height == page height
localparam TILE_WIDTH    = 8;
localparam NUM_TILES_X   = SCREEN_WIDTH / TILE_WIDTH;

localparam HCTR_BITS     = $clog2(SCREEN_WIDTH);
localparam PAGE_BITS     = $clog2(SCREEN_PAGES);
localparam TILE_X_BITS   = $clog2(NUM_TILES_X);
localparam TILE_NUM_BITS = $clog2(NUM_TILES_X * SCREEN_PAGES);

// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst, stop_update;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(stop_update), .out_debounced());
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// serial oled interface
// ----------------------------------------------------------------------------
wire serial_error, serial_ready;
wire [HCTR_BITS - 1 : 0] x_pix;
wire [PAGE_BITS - 1 : 0] y_page;  // line

oled_serial #(.SERIAL_BITS(8),
	.SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
	.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(SERIAL_CLK))
oled_mod (.in_clk(clk27), .in_rst(rst),
	.in_pixels(8'b0000_0001), .in_update(~stop_update),
	.inout_serial_clk(oled_scl), .inout_serial(oled_sda),
	.out_serial_error(serial_error), .out_serial_ready(serial_ready),
	.out_hpix(x_pix), .out_vpix(), .out_vpage(y_page));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// text interface (TODO)
// ----------------------------------------------------------------------------
logic [TILE_X_BITS - 1 : 0] tile_x;
logic [TILE_NUM_BITS - 1 : 0] tile_num;

assign tile_x = TILE_X_BITS'(x_pix / TILE_WIDTH);
assign tile_num = TILE_NUM_BITS'(y_page*NUM_TILES_X + tile_x);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
logic slow_clk;
assign led[0] = serial_error ? ~slow_clk : 1'b1;
assign led[1] = 1'b1;
assign led[2] = ~serial_ready;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// gpios
// ----------------------------------------------------------------------------
//assign ledr = { $size(ledr) { slow_clk } };
assign ledr[0] = ~stop_update;
//assign ledr[3:1] = y_page;
assign ledr[9:1] = 1'b0;
//assign oled_sda = 1'bz;
//assign oled_scl = 1'bz;
// ----------------------------------------------------------------------------


endmodule
