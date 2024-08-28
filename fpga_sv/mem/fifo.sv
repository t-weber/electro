/**
 * fifo buffer
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-aug-2024
 * @license see 'LICENSE' file
 */


module fifo
#(
	parameter ADDR_BITS = 3,
	parameter WORD_BITS = 8
 )
(
	// reset
	input wire in_rst,

	// clocks
	input wire in_clk_insert, in_clk_remove,

	// insert or remove an element
	input wire in_insert, in_remove,

	// data to inserts
	input wire [WORD_BITS - 1 : 0] in_data,

	//  data at the back pointer
	output wire [WORD_BITS - 1 : 0] out_back,

	// buffer empty?
	output wire out_empty
);


//-----------------------------------------------------------------------------
// buffer memory
localparam NUM_WORDS = 2**ADDR_BITS;
logic [WORD_BITS - 1 : 0] words [0 : NUM_WORDS - 1];

// front and back pointers
logic [ADDR_BITS - 1 : 0] fp = 1'b0, next_fp = 1'b0;
logic [ADDR_BITS - 1 : 0] bp = 1'b0, next_bp = 1'b0;

wire empty = (bp == fp ? 1'b1 : 1'b0);
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// outputs
assign out_back = words[bp];
assign out_empty = empty;
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
//
// front-pointer / element insertion flip-flops
//
always_ff@(posedge in_clk_insert) begin
	if(in_rst == 1'b1)
		fp <= 1'b0;
	else
		fp <= next_fp;
end


//
// front-pointer / element insertion combinatorics
//
always_comb begin
	next_fp = fp;

	if(in_insert == 1'b1) begin
		// write data to front pointer
		words[fp] = in_data;

		// increment front pointer
		next_fp = $size(fp)'(fp + 1'b1);
	end
end
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
//
// back-pointer / element removal flip-flops
//
always_ff@(posedge in_clk_remove) begin
	if(in_rst == 1'b1)
		bp <= 1'b0;
	else
		bp <= next_bp;
end


//
// back-pointer / element removal combinatorics
//
always_comb begin
	next_bp = bp;

	if(in_remove == 1'b1 && empty == 1'b0) begin
		// increment back pointer
		next_bp = $size(bp)'(bp + 1'b1);
	end
end
//-----------------------------------------------------------------------------

endmodule
