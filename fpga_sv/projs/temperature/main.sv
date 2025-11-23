/**
 * temperature sensor
 * @author Tobias Weber
 * @date 23-nov-2025
 * @license see 'LICENSE' file
 */


module temp_ctrl
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	input  [3:0] btn,
	output [5:0] led,

	// led matrix
	output seg_dat,
	output seg_sel,
	output seg_clk,

	// temperature sensor
	inout temp_dat
);


localparam MAIN_CLK      = 27_000_000;
localparam SERIAL_CLK    =  2_000_000;
localparam SLOW_CLK      =         10;

localparam SERIAL_BITS   = 16;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst, stop_update, show_hex;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(stop_update), .out_debounced());

debounce_button #(.STABLE_TICKS(64))
	debounce_btn0(.in_clk(clk27), .in_rst(rst),
		.in_signal(~btn[0]), .out_toggled(show_hex), .out_debounced());
// ----------------------------------------------------------------------------


// --------------------------------------------------------------------
// led matrix serial bus
// --------------------------------------------------------------------
wire serial_enable, serial_ready;
wire [SERIAL_BITS - 1 : 0] serial_in_parallel;
wire serial_next_word;

// instantiate serial module
serial_tx #(
	.BITS(SERIAL_BITS), .LOWBIT_FIRST(1'b0), .FALLING_EDGE(1'b0),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
	.SERIAL_CLK_INACTIVE(1'b0), .SERIAL_DATA_INACTIVE(1'b0)
)
serial_mod(
	.in_clk(clk27), .in_rst(rst),
	.in_enable(serial_enable), .out_ready(serial_ready),
	.out_clk(seg_clk), .out_serial(seg_dat),
	.in_parallel(serial_in_parallel), .out_next_word(serial_next_word)
);
// --------------------------------------------------------------------


// ----------------------------------------------------------------------------
// led matrix interface
// ----------------------------------------------------------------------------
wire update_leds = show_hex ? !stop_update : bcd_finished && !stop_update;
wire [31 : 0] displayed_temp = show_hex ? temp : bcd_temp;

ledmatrix #(.MAIN_CLK(MAIN_CLK), .BUS_BITS(SERIAL_BITS),
	.NUM_SEGS(8), .LEDS_PER_SEG(8), .TRANSPOSE(1'b1))
ledmatrix_mod (.in_clk(clk27), .in_rst(rst),
	.in_update(update_leds), .in_digits(displayed_temp),
	.in_bus_ready(serial_ready), .in_bus_next_word(serial_next_word),
	.out_bus_enable(serial_enable), .out_bus_data(serial_in_parallel),
	.out_seg_enable(seg_sel)
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
wire slow_clk;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// temperature
// ----------------------------------------------------------------------------
localparam TEMP_BITS = 24;
reg [TEMP_BITS - 1 : 0] temp = 1'b0;

temperature #(.MAIN_CLK(MAIN_CLK))
temp_sensor(.in_clk(clk27), .in_rst(rst),
	.inout_dat(temp_dat));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// bcd conversion
// ----------------------------------------------------------------------------
logic bcd_finished;
reg [8*4 - 1 : 0] bcd_temp;

bcd #(.IN_BITS(TEMP_BITS), .OUT_BITS(8*4), .NUM_BCD_DIGITS(8))
bcd_mod(.in_clk(clk27), .in_rst(rst),
	.in_num(temp), .out_bcd(bcd_temp),
	.in_start(1'b1), .out_finished(bcd_finished));
// ----------------------------------------------------------------------------



// ----------------------------------------------------------------------------
// status outputs
// ----------------------------------------------------------------------------
assign led[0] = ~serial_ready;
assign led[1] = ~stop_update;
assign led[2] = ~show_hex;
assign led[3] = btn[0];
assign led[4] = slow_clk;
assign led[5] = temp_dat;
// ----------------------------------------------------------------------------


endmodule
