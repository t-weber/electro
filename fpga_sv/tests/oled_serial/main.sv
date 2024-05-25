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


localparam WRITE_ADDR    = 8'h78; // 8'h7a;
localparam READ_ADDR     = 8'h79; // 8'h7b;

localparam MAIN_CLK      = 27_000_000;
localparam SERIAL_CLK    =    400_000;
localparam SLOW_CLK      =          1;

localparam SCREEN_WIDTH  = 128;
localparam SCREEN_HEIGHT = 64;
localparam SCREEN_PAGES  = SCREEN_HEIGHT / 8;

// tile height == page height
// # of y tiles == # of screen pages
localparam TILE_WIDTH    = 8;
localparam NUM_TILES_X   = SCREEN_WIDTH / TILE_WIDTH;

localparam SERIAL_BITS     = 8;
localparam HCTR_BITS       = $clog2(SCREEN_WIDTH);
localparam PAGE_BITS       = $clog2(SCREEN_PAGES);
localparam TILE_X_BITS     = $clog2(NUM_TILES_X);
localparam TILE_NUM_BITS   = $clog2(NUM_TILES_X * SCREEN_PAGES);
localparam TILE_WIDTH_BITS = $clog2(TILE_WIDTH);

// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst, stop_update;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(stop_update), .out_debounced());
// ----------------------------------------------------------------------------


// --------------------------------------------------------------------
// serial bus
// --------------------------------------------------------------------
wire serial_enable, serial_ready, serial_error;
wire [SERIAL_BITS - 1 : 0] serial_in_parallel;
wire serial_next_word;

// instantiate serial module
serial_2wire #(
	.BITS(SERIAL_BITS), .LOWBIT_FIRST(0),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
`ifdef __IN_SIMULATION__
	.IGNORE_ERROR(1'b1)
`else
	.IGNORE_ERROR(1'b0)
`endif
)
serial_mod(
	.in_clk(clk27), .in_rst(rst), .out_err(serial_error),
	.in_enable(serial_enable), .in_write(1'b1), .out_ready(serial_ready),
	.in_addr_write(WRITE_ADDR), .in_addr_read(READ_ADDR),
	.inout_serial_clk(oled_scl), .inout_serial(oled_sda),
	.in_parallel(serial_in_parallel), .out_parallel(),
	.out_next_word(serial_next_word)
);
// --------------------------------------------------------------------


// ----------------------------------------------------------------------------
// serial oled interface
// ----------------------------------------------------------------------------
wire [HCTR_BITS - 1 : 0] x_pix;   // pixel number
wire [PAGE_BITS - 1 : 0] y_page;  // line number

wire [0 : SERIAL_BITS - 1] char_line;

oled_serial #(.MAIN_CLK(MAIN_CLK), .BUS_BITS(SERIAL_BITS),
	.SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT))
oled_mod (.in_clk(clk27), .in_rst(rst),
	.in_pixels(/*8'b0000_0001*/ char_line), .in_update(~stop_update),
	.in_bus_ready(serial_ready), .in_bus_next_word(serial_next_word),
	.out_bus_enable(serial_enable), .out_bus_data(serial_in_parallel),
	.out_hpix(x_pix), .out_vpix(), .out_vpage(y_page));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// text interface
// ----------------------------------------------------------------------------
logic [TILE_X_BITS - 1 : 0] tile_x;
logic [TILE_WIDTH_BITS - 1 : 0] tile_pix_x;
logic [TILE_NUM_BITS - 1 : 0] tile_num;

assign tile_x = TILE_X_BITS'(x_pix / TILE_WIDTH);
assign tile_pix_x = TILE_WIDTH_BITS'(x_pix % TILE_WIDTH);
assign tile_num = TILE_NUM_BITS'(y_page*NUM_TILES_X + tile_x);

logic [7 : 0] cur_char; //= 8'h31;

// font rom
font font_rom(.in_char(7'(cur_char)),
	.in_x(1'b0), .in_y(tile_pix_x),
	.out_line(char_line), .out_pixel());

// text buffer in rom
textmem #(.ADDR_BITS(TILE_NUM_BITS))
textmem_mod (.in_addr(tile_num), .out_data(cur_char));
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
