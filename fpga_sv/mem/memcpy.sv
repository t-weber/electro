/**
 * copy memory from one location to another
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 23-aug-2025
 * @license see 'LICENSE' file
 */

`default_nettype /*wire*/ none


module memcpy
#(
  parameter NUM_WORDS = 2**8,
  parameter ADDR_BITS = 8 /*$clog2(NUM_WORDS)*/,
  parameter WORD_BITS = 8
)
(
	input wire in_clk,
	input wire in_rst,

	input wire [WORD_BITS - 1 : 0] in_word,
	output wire [WORD_BITS - 1 : 0] out_word,
	output wire [ADDR_BITS - 1 : 0] out_addr,

	output wire out_read_enable,
	output wire out_write_enable,
	input wire in_read_finished,
	input wire in_write_finished,

	output wire out_finished
);


typedef enum bit [2 : 0]
{
	READ, WRITE,
	NEXT_WORD, DONE
} t_state;


t_state state = READ, next_state = READ;
logic [ADDR_BITS - 1 : 0] word_ctr = 1'b0, next_word_ctr = 1'b0;
logic [WORD_BITS - 1 : 0] word = 1'b0, next_word = 1'b0;


always_ff@(posedge in_clk) begin
	if(in_rst == 1'b1) begin
		state = READ;
		word_ctr <= 1'b0;
		word <= 1'b0;
	end else begin
		state <= next_state;
		word_ctr <= next_word_ctr;
		word <= next_word;
	end

	//$display("state=%s, addr=%h, data=%h", state.name(), word_ctr, word);
end


// copying finished?
assign out_finished = (state == DONE);
assign out_addr = word_ctr;
assign out_read_enable = (state == READ);
assign out_write_enable = (state == WRITE);
assign out_word = word;


always_comb begin
	next_state = state;
	next_word_ctr = word_ctr;
	next_word = word;

	case(state)
		READ: begin
			if(in_read_finished == 1'b1) begin
				next_word = in_word;
				next_state = WRITE;
			end
		end

		WRITE: begin
			if(in_write_finished == 1'b1) begin
				next_state = NEXT_WORD;
			end
		end

		NEXT_WORD: begin
			if(word_ctr == NUM_WORDS - 1'b1) begin
				next_state = DONE;
			end else begin
				next_word_ctr = word_ctr + 1'b1;
				next_state = READ;
			end
		end

		DONE: begin
		end
	endcase
end


endmodule
