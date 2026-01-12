/**
 * serial 2-wire text display test
 * @author Tobias Weber
 * @date 6-jan-2026
 * @license see 'LICENSE' file
 */

//`default_nettype /*wire*/ none

module textlcd2_test
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	output [5:0] led,

	// seven segment leds
	inout txtlcd_scl,
	inout txtlcd_sda
);


localparam longint MAIN_CLK   = 27_000_000;
localparam longint SERIAL_CLK =    100_000;
localparam longint SLOW_CLK   =          2;

localparam byte SERIAL_BITS   = 8;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(key[1]), .out_debounced(rst));
// ----------------------------------------------------------------------------


// --------------------------------------------------------------------
// text lcd serial bus
// --------------------------------------------------------------------
wire serial_enable, serial_ready, serial_error;
wire [SERIAL_BITS - 1 : 0] serial_data, serial_data_in;
wire serial_next_word;

// instantiate serial module
serial_2wire #(
	.BITS(SERIAL_BITS), .ADDR_BITS(SERIAL_BITS),
	.LOWBIT_FIRST(0), .TRANSMIT_ADDR(1),
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
	//.in_addr_write(8'h26), .in_addr_read(8'h27),
	.in_addr_write(8'h4e), .in_addr_read(8'h4f),
	.inout_serial_clk(txtlcd_scl), .inout_serial(txtlcd_sda),
	.in_parallel(serial_data), .out_parallel(serial_data_in),
	.out_next_word(serial_next_word)
);
// --------------------------------------------------------------------


// ----------------------------------------------------------------------------
// text lcd serial interface
// ----------------------------------------------------------------------------
wire update;
assign update = 1'b1;

// instantiate lcd module
txtlcd2 #(
	.MAIN_CLK(MAIN_CLK), .LCD_SIZE(4*20)
)
lcd_mod(
	.in_clk(clk27), .in_rst(rst),
	.in_update(update), //.in_bus_data(serial_data_in),
	.in_bus_next(serial_next_word), .in_bus_ready(serial_ready),
	.out_bus_data(serial_data), .out_bus_enable(serial_enable)
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
wire slow_clk;

clkpulsegen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk), .out_re());
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// outputs
// ----------------------------------------------------------------------------
assign led[0] = serial_error ? ~slow_clk : 1'b1;
assign led[1] = ~serial_ready;
assign led[2] = ~txtlcd_scl;
assign led[3] = ~txtlcd_sda;
assign led[5:4] = 2'b11;
// ----------------------------------------------------------------------------


endmodule
