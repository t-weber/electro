/**
 * pseudo-random numbers via lfsr
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date jan-2021, 28-july-2024
 * @license see 'LICENSE' file
 * @see https://de.wikipedia.org/wiki/Linear_r%C3%BCckgekoppeltes_Schieberegister
 */

module lfsr
#(
		// number of bits for shift register
		parameter BITS = 8,

		// initial seed
		parameter [BITS] SEED = BITS'(8'b0000_0101),

		// bits to xor
		parameter [BITS] FUNC = BITS'(8'b0000_0110)
 )
(
		// clock and reset
		input wire in_clk, in_rst = 1'b0,

		// initial value
		input wire [BITS] in_seed = BITS'(8'b0000_0101),

		// enable setting of new seed
		input wire in_setseed = 1'b0,

		// get next value
		input wire in_nextval = 1'b0,

		// final value
		output reg [BITS] out_val = SEED
);



/*automatic*/ function [BITS] get_next_val(logic [BITS] vec);
	/*automatic*/ logic theval;
	theval = vec[BITS - 1];

	for(bit [$clog2(BITS) + 1] bit_idx = 1'b0; bit_idx < BITS; ++bit_idx)
	begin
		if(FUNC[BITS - 1 - bit_idx] == 1'b1)
			theval = theval ^ vec[BITS - 1 - bit_idx];
	end

	get_next_val = (theval << (BITS-1)) | (vec >> 1'b1);
endfunction



always_ff@(posedge in_clk) begin
	// reset to initial seed
	if(in_rst == 1'b1)
		out_val <= SEED;
	// set new seed
	else if(in_setseed == 1'b1)
		out_val <= in_seed;
	// next value
	else if(in_nextval == 1'b1)
		out_val <= get_next_val(out_val);
end


endmodule
