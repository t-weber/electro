/**
 * divider
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 7-January-2024
 * @license see 'LICENSE' file
 */

module divider
#(
	parameter BITS = 8
)
(
	// clock and reset
	input wire in_clk, in_rst,

	// start signal
	input wire in_start,

	// inputs: divider and divisor
	input wire [BITS-1 : 0] in_a, in_b,

	// outputs: quotient and remainder
	output wire [BITS-1 : 0] out_quot, out_rem,

	// calculation finished?
	output wire out_finished
);


// divider states
typedef enum
{
	Reset,      // start division
	CheckSub,   // check if a subtraction is possible 
	Sub,        // subtract divisor
	Finished    // division finished
} t_state;

t_state state = Reset, state_next = Reset;


logic [BITS-1 : 0] quotient, quotient_next;   // current quotient value
logic [BITS-1 : 0] remainder, remainder_next; // current remainder value
logic [BITS-1 : 0] b_2scomp;                  // 2s complement of divisior, in_b


// use adder module to subtract the divisor from the remainder
logic [BITS-1 : 0] remainder_sub;
ripplecarryadder #(.BITS(BITS)) sum(
	.in_a(remainder), .in_b(b_2scomp), .out_sum(remainder_sub));


// output signals
assign out_quot = quotient;
assign out_rem = remainder;
assign out_finished = (state==Finished ? 1'b1 : 1'b0);

assign b_2scomp = ~in_b + 1'b1;


// clock process
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst) begin
		state <= Reset;
		quotient <= 0;
		remainder <= 0;
	end

	else if(in_clk) begin
		state <= state_next;
		quotient <= quotient_next;
		remainder <= remainder_next;
	end
end


// calculation process
always_comb begin
	// save registers
	state_next = state;
	quotient_next = quotient;
	remainder_next = remainder;

	unique case(state)
		// set remainder := dividend
		Reset:
			begin
				quotient_next = 0;
				remainder_next = in_a;
				state_next = CheckSub;
			end

		// check if the divisor can be subtracted from the remainder
		CheckSub:
			begin
				if(remainder >= in_b) begin
					state_next = Sub;
				end else begin
					state_next = Finished;
				end
			end

		// subtract the divisor from the remainder
		Sub:
			begin
				// use internal adder
				//remainder_next = remainder + b_2scomp;

				// alternatively use internal subtractor
				//remainder_next = remainder - in_b;

				// alternatively use adder module
				remainder_next = remainder_sub;

				quotient_next = quotient + 1;
				state_next = CheckSub; 
			end

		Finished:
			// wait for start signal
			if(in_start) begin
				state_next = Reset;
			end
	endcase
end

endmodule
