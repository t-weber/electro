/**
 * parallel-in, serial-out
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 13-april-2025
 * @license see 'LICENSE' file
 *
 * @see: https://en.wikipedia.org/wiki/Shift_register
 */


module piso
#(
	parameter BITS        = 8,
	parameter SHIFT_RIGHT = 1
 )
(
	// reset and clock
	input wire in_rst, in_clk,

	// parallel input
	input wire [BITS - 1 : 0] in_parallel,
	input wire in_capture,
	input wire in_rotate,

	// serial output
	output wire out_serial
);


//-----------------------------------------------------------------------------
// shift register
logic [BITS - 1 : 0] shiftreg, next_shiftreg;

// output
assign out_parallel = shiftreg;
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
//
// flip-flops
//
always_ff@(posedge in_clk) begin
	if(in_rst == 1'b1)
		shiftreg <= 1'b0;
	else
		shiftreg <= next_shiftreg;
end


//
// combinatorics
//
generate if(SHIFT_RIGHT == 1'b1)
begin

	assign out_serial = next_shiftreg[0];

	always_comb begin
		// default
		next_shiftreg = shiftreg;

		// capture parallel input
		if(in_capture == 1'b1) begin
			next_shiftreg = in_parallel;
		end else begin
			if(in_rotate == 1'b1)
				next_shiftreg[BITS - 1] = shiftreg[0];
			else
				next_shiftreg[BITS - 1] = 1'b0;

			// shift right
			for(logic[$clog2(BITS) : 0] idx = 1; idx < BITS; ++idx)
				next_shiftreg[idx - 1] = shiftreg[idx];
		end
	end

end else begin

	assign out_serial = next_shiftreg[BITS - 1];

	always_comb begin
		// default
		next_shiftreg = shiftreg;

		// capture parallel input
		if(in_capture == 1'b1) begin
			next_shiftreg = in_parallel;
		end else begin
			if(in_rotate == 1'b1)
				next_shiftreg[0] = shiftreg[BITS - 1];
			else
				next_shiftreg[0] = 1'b0;

			// shift left
			for(logic[$clog2(BITS) : 0] idx = 1; idx < BITS; ++idx)
				next_shiftreg[idx] = shiftreg[idx - 1];
		end
	end

end endgenerate
//-----------------------------------------------------------------------------


endmodule
