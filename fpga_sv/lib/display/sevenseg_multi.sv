/**
 * multiplexed seven segment leds
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 21-apr-2025
 * @license see 'LICENSE' file
 */

module sevenseg_multi
#(
	parameter NUM_LEDS = 2,

	parameter ZERO_IS_ON = 0,
	parameter INVERSE_NUMBERING = 0,
	parameter ROTATED = 0
)
(
	// clock and reset
	input wire in_clk, in_rst,

	input wire [NUM_LEDS*4 - 1 : 0] in_digits,

	output wire [6:0] out_leds,
	output wire [$clog2(NUM_LEDS) - 1 : 0] out_sel
);



reg [$clog2(NUM_LEDS) - 1 : 0] counter =  1'b0, next_counter = 1'b0;
assign out_sel = counter;


always_ff@(posedge in_clk) begin
	// reset
	if(in_rst == 1'b1)
		counter <= 1'b0;

	// clock
	else
		counter <= next_counter;
end



always_comb begin
	if(counter == NUM_LEDS)
		next_counter = 1'b0;
	else
		next_counter = counter + 1'b1;
end



// generate seven segment module
sevenseg #(
	.ZERO_IS_ON(ZERO_IS_ON), .INVERSE_NUMBERING(INVERSE_NUMBERING),
	.ROTATED(ROTATED)
)
sevenseg_mod(
	.in_digit(in_digits[(counter + 1'b1)*4 - 1'b1 -: 4]), .out_leds(out_leds)
);


endmodule
