/**
 * pixel lc display test
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 3-may-2025
 * @license see 'LICENSE' file
 */


module main
(
	// main clock
	input clk27,

	// lcd module
	output lcd_cs, lcd_reset,
	output lcd_regsel,
	output lcd_scl, lcd_sda,

	// buttons and leds
	input [1:0] key,
	output [2:0] led,
	output [4:0] ledr
);


localparam MAIN_CLK     = 27_000_000;
localparam SERIAL_CLK   = 10_000;

localparam BITS      = 8;
localparam LCD_COLS  = 128;
localparam LCD_PAGES = 8;


wire reset = ~key[0];
wire update = ~key[1];
wire serial_clk_raw;


// --------------------------------------------------------------------
// leds
// --------------------------------------------------------------------
assign ledr[0] = reset;
assign ledr[1] = update;
assign ledr[2] = serial_clk_raw;
assign ledr[3] = clk27;
assign ledr[4] = 1'b0;
assign led = 3'b111;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// lcd serial bus
// --------------------------------------------------------------------
wire serial_enable, serial_ready;
wire [BITS - 1 : 0] serial_data, serial_data_in;
wire serial_next;
wire transmitting;

// instantiate serial module
serial #(
	.BITS(BITS), .LOWBIT_FIRST(1'b0),
	.KEEP_SERIAL_CLK_RUNNING(1'b1),
	.TO_FPGA_FALLING_EDGE(1'b1), .FROM_FPGA_FALLING_EDGE(1'b1), 
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK)
)
serial_mod(
	.in_clk(clk27), .in_rst(reset), .in_enable(serial_enable),
	.out_ready(serial_ready),
	.out_clk(lcd_scl), .out_serial(lcd_sda),
	.in_serial(none), .out_transmitting(transmitting),
	.in_parallel(serial_data), .out_parallel(serial_data_in),
	.out_next_word(serial_next), .out_word_finished(),
	.out_clk_raw(serial_clk_raw)
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// lcd module
// --------------------------------------------------------------------
wire [7 : 0] ram_read = 8'b1000_0001;
assign lcd_cs = ~transmitting;  //1'b0;


// instantiate lcd module
pixlcd_3wire #(
	.MAIN_CLK(MAIN_CLK), .LCD_COLS(LCD_COLS), .LCD_PAGES(LCD_PAGES)
)
lcd_mod(
	.in_clk(clk27), .in_rst(reset),
	.in_update(update), .in_bus_data(serial_data_in),
	.in_bus_next(serial_next), .in_bus_ready(serial_ready),
	.out_bus_data(serial_data), .out_bus_enable(serial_enable),
	.in_mem_word(ram_read),
	.out_lcd_reset(lcd_reset), .out_lcd_regsel(lcd_regsel)
);
// --------------------------------------------------------------------


endmodule
