/**
 * text lc display test
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 21-april-2025
 * @license see 'LICENSE' file
 *
 * fpga gpio pins:
 * ==============
 *    blue |   green || violet
 *    ○○○○○●○○ ... ○○●●
 *    ○○○○○●○○ ... ○○●●
 *     red |  orange || yellow
 *
 * lcd pins:
 * ========
 *   orange |    | yellow
 *          ●○○○●●●○○ ...
 *        green | | violet
 */


module main
(
	// main clock
	input clk50,

	// lcd module
	output lcd_scl, lcd_rst,
	output lcd_sda_o,
	input lcd_sda_i,

	// buttons and leds
	input [3:0] btn,
	output [7:0] led,
	output [6:0] seg,
	output seg_sel
);


localparam MAIN_CLK     = 50_000_000;
localparam SERIAL_CLK   = 1_000_000;
localparam SEVENSEG_CLK = 100;

localparam BITS     = 8;
localparam LCD_SIZE = 4*20;


wire reset = ~btn[0];
wire update = ~btn[1];
wire serial_clk_raw;


// --------------------------------------------------------------------
// leds
// --------------------------------------------------------------------
assign led[0] = ~reset;
assign led[1] = ~update;
assign led[5:2] = 4'b1111;
assign led[6] = ~serial_clk_raw;
assign led[7] = ~clk50;

wire [7 : 0] flags;

logic sevenseg_clk = 1'b0;

clkgen #(
	.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SEVENSEG_CLK),
	.CLK_INIT(1'b1)
)
sevenseg_clk_mod
(
	.in_clk(clk50), .in_rst(reset),
	.out_clk(sevenseg_clk)
);

sevenseg_multi #(
	.NUM_LEDS(2), .ZERO_IS_ON(1'b1),
	.INVERSE_NUMBERING(1'b1), .ROTATED(1'b1))
sevenseg_mod(.in_clk(sevenseg_clk), .in_rst(reset),
	.in_digits(flags), .out_leds(seg), .out_sel(seg_sel));
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// lcd serial bus
// --------------------------------------------------------------------
wire serial_enable, serial_ready;
wire [BITS - 1 : 0] serial_data, serial_data_in;
wire serial_next;

// instantiate serial module
serial #(
	.BITS(BITS), .LOWBIT_FIRST(1'b1),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK)
)
serial_mod(
	.in_clk(clk50), .in_rst(reset), .in_enable(serial_enable),
	.out_ready(serial_ready), .out_clk(lcd_scl),
	.out_serial(lcd_sda_o), .in_serial(lcd_sda_i),
	.in_parallel(serial_data), .out_parallel(serial_data_in),
	.out_next_word(serial_next), .out_word_finished(),
	.out_clk_raw(serial_clk_raw)
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// lcd module
// --------------------------------------------------------------------
wire [7 : 0] ram_read = 8'h41 + ram_addr[6 : 0];  // 'A' + ...
wire [6 : 0] ram_addr;
//assign led[6:0] = ram_addr;


// instantiate lcd module
txtlcd_3wire #(
	.MAIN_CLK(MAIN_CLK), .LCD_SIZE(LCD_SIZE)
)
lcd_mod(
	.in_clk(clk50), .in_rst(reset),
	.in_update(update), .in_bus_data(serial_data_in),
	.in_bus_next(serial_next), .in_bus_ready(serial_ready),
	.out_bus_data(serial_data), .out_bus_enable(serial_enable),
	.in_mem_word(ram_read), .out_mem_addr(ram_addr),
	.out_busy_flag(flags), .out_lcd_reset(lcd_rst)
);
// --------------------------------------------------------------------


endmodule
