/**
 * synchronise data from a slow to a fast clock domain
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-October-2025
 * @license see 'LICENSE' file
 */

module syncdata
#(
	parameter int BITS  = 8,
	parameter int STEPS = 4
)
(
	input  wire in_clk, in_rst,
	input  wire [BITS - 1 : 0] in_data,
	output wire [BITS - 1 : 0] out_data
);


/*bit [$clog2(STEPS) : 0]*/ int shift_idx;
logic [0 : STEPS - 1][BITS - 1 : 0] shiftreg;

assign out_data = shiftreg[STEPS - 1];


// synchronise to clock
always_ff@(posedge in_clk/*, posedge in_rst*/) begin
	if(in_rst == 1'b1) begin
		shiftreg <= 1'b0;
	end

	else /*if(in_clk == 1)*/ begin
		shiftreg[0] <= in_data;

		for(shift_idx = 1; shift_idx < STEPS; ++shift_idx) begin
			shiftreg[shift_idx] <= shiftreg[shift_idx - 1];
		end
	end
end


endmodule
