/**
 * testing external clock
 * @author Tobias Weber
 * @date 8-aug-2024
 * @license see 'LICENSE' file
 */

module extclk
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	output [2:0] led,

	// gpios
	input  [3:0] gpiol,
	output [9:0] gpior
);


localparam MAIN_CLK = 27_000_000;
localparam SLOW_CLK =          1;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst, dir;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(dir));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
logic slow_clk;
assign led[0] = ~slow_clk;
assign led[1] = ~rst;
assign led[2] = ~dir;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// external clock
// ----------------------------------------------------------------------------
wire ext_clk;
//assign ext_clk = gpiol[0];

edgedet #(.POS_EDGE(1), .NUM_STEPS(4))
edge_det (.in_clk(clk27), .in_rst(rst),
	.in_signal(gpiol[0]), .out_edge(ext_clk));

bit [5:0] counter;
assign gpior[5:0] = counter;
assign gpior[9:6] = 1'b0;

always@(posedge ext_clk, posedge rst) begin
	if(rst == 1'b1)
		counter <= 6'b0;
	else begin
		if(dir == 1'b0)
			counter <= counter + 6'b1;
		else
			counter <= counter - 6'b1;
	end
end
// ----------------------------------------------------------------------------


endmodule
