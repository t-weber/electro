/**
 * serial-in, parallel-out
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 13-april-2025
 * @license see 'LICENSE' file
 *
 * @see: https://en.wikipedia.org/wiki/Shift_register
 */


module sipo
#(
	parameter BITS        = 8,
	parameter SHIFT_RIGHT = 1
 )
(
	// reset and clock
	input wire in_rst, in_clk,

	// serial input
	input wire in_serial,

	// parallel output
	output wire [BITS - 1 : 0] out_parallel
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
	// write serial signal in first shift register bit
	assign next_shiftreg[BITS - 1] = in_serial;
end else begin
	// write serial signal in first shift register bit
	assign next_shiftreg[0] = in_serial;
end endgenerate


genvar idx;
generate for(idx = BITS - 1; idx >= 1 ; --idx)
begin : shiftloop
	if(SHIFT_RIGHT == 1'b1)
		assign next_shiftreg[idx - 1] = shiftreg[idx];
	else
		assign next_shiftreg[idx] = shiftreg[idx - 1];
end endgenerate
//-----------------------------------------------------------------------------


endmodule
