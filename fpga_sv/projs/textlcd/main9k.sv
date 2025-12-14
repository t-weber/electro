/**
 * text lc display test
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 21-april-2025
 * @license see 'LICENSE' file
 *
 * fpga gpio pins (9k):
 * ===================
 *    ○○○○●●●●○○ ...
 *        ||||
 *        |||violet
 *        ||yellow
 *        |green
 *        orange
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
	input clk27,

	// lcd module
	output txtlcd_scl, txtlcd_rst,
	output txtlcd_sda_o,
	input txtlcd_sda_i,

	// buttons and leds
	input [1:0] key,
	output [5:0] led,
    output [7:0] ledg
);


localparam longint MAIN_CLK   = 27_000_000;
localparam longint SERIAL_CLK = 1_000_000;

localparam byte BITS     = 8;
localparam int  LCD_SIZE = 4*20;


wire reset = ~key[0];
wire update = ~key[1];
wire serial_clk_raw;


// --------------------------------------------------------------------
// leds
// --------------------------------------------------------------------
assign led[0] = ~reset;
assign led[1] = ~update;
assign led[2] = ~serial_clk_raw;
assign led[3] = ~clk27;
assign led[4] = 1'b0;
assign led[5] = 1'b0;

wire [7 : 0] flags;
assign ledg = flags;
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
	.in_clk(clk27), .in_rst(reset), .in_enable(serial_enable),
	.out_ready(serial_ready), .out_clk(txtlcd_scl),
	.out_serial(txtlcd_sda_o), .in_serial(txtlcd_sda_i),
	.in_parallel(serial_data), .out_parallel(serial_data_in),
	.out_next_word(serial_next), .out_word_finished(),
	.out_clk_raw(serial_clk_raw), .out_transmitting()
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
	.MAIN_CLK(MAIN_CLK), .LCD_SIZE(LCD_SIZE),
    .READ_BUSY_FLAG(1'b1)
)
lcd_mod(
	.in_clk(clk27), .in_rst(reset),
	.in_update(update), .in_bus_data(serial_data_in),
	.in_bus_next(serial_next), .in_bus_ready(serial_ready),
	.out_bus_data(serial_data), .out_bus_enable(serial_enable),
	.in_mem_word(ram_read), .out_mem_addr(ram_addr),
	.out_busy_flag(flags), .out_lcd_reset(txtlcd_rst)
);
// --------------------------------------------------------------------


endmodule
