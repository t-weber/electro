/**
 * testing gpios
 * @author Tobias Weber
 * @date 12-may-2024
 * @license see 'LICENSE' file
 */

module gpio
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	output [2:0] led,

	// gpios
	//output [5:0] gpiol,
	//output [6:0] gpior
	output [3:0] gpiol,
	output [9:0] gpior
);


localparam MAIN_CLK = 27_000_000;
localparam SLOW_CLK =          1;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst, key1;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(key1));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
logic slow_clk;
assign led[0] = ~slow_clk;
assign led[1] = ~rst;
assign led[2] = ~key1;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// gpios
// ----------------------------------------------------------------------------
assign gpiol = { $size(gpiol) { slow_clk } };
assign gpior = { $size(gpior) { slow_clk } };
// ----------------------------------------------------------------------------


endmodule

