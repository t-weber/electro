/**
 * synchronise bit from a slow to a fast clock domain
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-October-2025
 * @license see 'LICENSE' file
 */

module syncbit
#(
	parameter int STEPS = 4
)
(
	input  wire in_clk, in_rst,
	input  wire in_bit,
	output wire out_bit
);


/*bit [$clog2(STEPS) : 0]*/ int shift_idx;
logic [0 : STEPS - 1] shiftreg;

assign out_bit = shiftreg[STEPS - 1];


// synchronise to clock
always_ff@(posedge in_clk/*, posedge in_rst*/) begin
	if(in_rst == 1'b1) begin
		shiftreg <= 1'b0;
	end

	else /*if(in_clk == 1)*/ begin
		shiftreg[0] <= in_bit;

		for(shift_idx = 1; shift_idx < STEPS; ++shift_idx) begin
			shiftreg[shift_idx] <= shiftreg[shift_idx - 1];
		end
	end
end


endmodule
