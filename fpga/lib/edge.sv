/**
 * get edge of a signal
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 22-April-2021
 * @license see 'LICENSE' file
 */

module edgedet
#(
	parameter NUM_STEPS = 4,
	parameter POS_EDGE = 1
)
(
	input wire in_clk,
	input wire in_signal,
	output wire out_edge
);


logic [0 : NUM_STEPS-1] shiftreg;
integer shift_idx;


// output edge
generate if(POS_EDGE == 1)
	assign out_edge = shiftreg[NUM_STEPS-2] & (~shiftreg[NUM_STEPS-1]);
else
	assign out_edge = (~shiftreg[NUM_STEPS-2]) & shiftreg[NUM_STEPS-1];
endgenerate


// synchronise to clock
always@(posedge in_clk) begin
	shiftreg[0] <= in_signal;

	for(shift_idx=1; shift_idx<NUM_STEPS; ++shift_idx) begin
		shiftreg[shift_idx] <= shiftreg[shift_idx-1];
	end
end


endmodule
