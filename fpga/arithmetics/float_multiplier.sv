/**
 * float multiplier
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 16-June-2023
 * @license see 'LICENSE' file
 */

module float_multiplier
#(
	parameter BITS = 32,
	parameter EXP_BITS = 8,
	parameter MANT_BITS = BITS-EXP_BITS - 1,
	parameter EXP_BIAS = $pow(2, EXP_BITS-1) - 1
)
(
	// clock and reset
	input wire in_clk, in_rst,

	// start signal
	input wire in_start,

	// inputs
	input wire [BITS-1 : 0] in_a, in_b,

	// output
	output wire [BITS-1 : 0] out_prod,

	// calculation finished?
	output wire out_finished
);


// multiplier states
typedef enum
{
	Reset,    // start multiplication
	Mult,     // perform the multiplication
	Norm,     // normalise float
	Finished  // multiplication finished
} t_state;

t_state state = Reset, state_next = Reset;


// input values
logic [EXP_BITS-1 : 0] a_exp;
logic [EXP_BITS-1 : 0] b_exp;
logic [MANT_BITS : 0] a_mant;
logic [MANT_BITS : 0] b_mant;

assign a_exp = in_a[BITS-2 : BITS-1-EXP_BITS];
assign b_exp = in_b[BITS-2 : BITS-1-EXP_BITS];
assign a_mant = in_a[MANT_BITS-1 : 0] | (1 << MANT_BITS);
assign b_mant = in_b[MANT_BITS-1 : 0] | (1 << MANT_BITS);


// multiplied values
logic sign;
logic [EXP_BITS-1 : 0] exp, exp_next;
logic [MANT_BITS-1 : 0] mant, mant_next;


// output product
assign sign = in_a[BITS-1] ^ in_b[BITS-1];
assign out_prod = { sign, exp, mant[MANT_BITS-1 : 0]};
assign out_finished = (state==Finished ? 1'b1 : 1'b0);


// clock process
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst) begin
		state <= Reset;
		exp <= 0;
		mant <= 0;
	end

	else if(in_clk) begin
		state <= state_next;
		exp <= exp_next;
		mant <= mant_next;
	end
end


// calculation process
always_comb begin
	// save registers
	state_next = state;
	exp_next = exp;
	mant_next = mant;

	case(state)
		Reset:
			begin
				exp_next = 0;
				mant_next = 0;
				state_next = Mult;
			end

		Mult:
			begin
				// exponent
				exp_next = a_exp + b_exp - EXP_BIAS;

				// mantissa
				mant_next = (a_mant * b_mant) >> MANT_BITS;

				state_next = Norm;
			end

		Norm:
			begin
				state_next = Finished;
			end

		Finished:
			// wait for start signal
			if(in_start) begin
				state_next = Reset;
			end
	endcase
end

endmodule
