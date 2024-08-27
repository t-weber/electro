/**
 * stack (lifo buffer)
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-aug-2024
 * @license see 'LICENSE' file
 */


module stack
#(
	parameter ADDR_BITS = 3,
	parameter WORD_BITS = 8
 )
(
	// clock and reset
	input wire in_clk, in_rst,

	// 00 : nop
	// 01 : push
	// 10 : pop
	input wire [1 : 0] in_cmd,

	// data to push
	input wire [WORD_BITS - 1 : 0] in_data,

	// data at the top of the stack
	output wire [WORD_BITS - 1 : 0] out_top,

	// ready to input command
	output wire out_ready
);


// stack memory
localparam NUM_WORDS = 2**ADDR_BITS;
logic [WORD_BITS - 1 : 0] words [0 : NUM_WORDS - 1];

// input buffer
logic [WORD_BITS - 1 : 0] data = 1'b0, next_data = 1'b0;

// stack pointer
logic [ADDR_BITS - 1 : 0] sp = 1'b0, next_sp = 1'b0;

logic ready = 1'b0;

typedef enum
{
	WaitCommand,
	Push, Push2,
	Pop
} t_state;

t_state state = WaitCommand, next_state = WaitCommand;


// output data at stack pointer
assign out_top = words[sp];
assign out_ready = ready;


always_ff@(posedge in_clk) begin
	if(in_rst == 1'b1) begin
		state <= WaitCommand;
		data <= 1'b0;
		sp <= 1'b0;
	end else begin
		state <= next_state;
		data <= next_data;
		sp <= next_sp;
	end
end


always_comb begin
	next_state = state;
	next_sp = sp;
	next_data = data;

	ready = 1'b0;

	case(state)
		WaitCommand: begin
			case(in_cmd)
				2'b01: next_state = Push;
				2'b10: next_state = Pop;
				default: ready = 1'b1;
			endcase
		end

		Push: begin
			// decrement stack pointer
			next_sp = $size(sp)'(sp - 1'b1);
			next_state = Push2;

			// buffer data
			next_data = in_data;
		end

		Push2: begin
			// write data to stack pointer
			words[sp] = data;
			next_state = WaitCommand;
		end

		Pop: begin
			// increment stack pointer
			next_sp = $size(sp)'(sp + 1'b1);
			next_state = WaitCommand;
		end
	endcase
end

endmodule
