/**
 * testing leds
 * @author Tobias Weber
 * @date 12-may-2024
 * @license see 'LICENSE' file
 */

module leds
(
	// main clock
	input clk27,

	input  [1 : 0] key,

	// leds
	output [5 : 0] led,
	output [7 : 0] ledg
);


localparam MAIN_CLK = 27_000_000;
localparam SLOW_CLK =          4;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
wire slow_clk;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
// ----------------------------------------------------------------------------


logic [7 : 0] shiftreg = 1'b1, shiftreg_next = 1'b1;
logic shiftdir = 1'b1, shiftdir_next = 1'b1;

always_ff@(posedge slow_clk, posedge rst) begin
	if(rst == 1'b1) begin
		shiftreg <= 1'b1;
		shiftdir <= 1'b1;
	end else begin
		shiftreg <= shiftreg_next;
		shiftdir <= shiftdir_next;
	end
end


always_comb begin
	shiftdir_next = shiftdir;
	shiftreg_next = shiftreg;

	if(shiftreg == (1'b1 << ($size(ledg) - 2)) && shiftdir == 1'b1)
		shiftdir_next = 1'b0;
	if(shiftreg == 2'b10 && shiftdir == 1'b0)
		shiftdir_next = 1'b1;

	if(shiftdir == 1'b1)
		shiftreg_next = (shiftreg << 1'b1);
	else
		shiftreg_next = (shiftreg >> 1'b1);
end


assign ledg = shiftreg;
assign led = ~shiftreg[5:0];


endmodule
