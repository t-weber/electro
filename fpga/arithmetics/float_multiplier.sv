/**
 * float multiplier
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 10-June-2023
 * @license see 'LICENSE' file
 */

module float_multiplier
#(
	parameter BITS = 32,
	parameter EXP_BITS = 8,
	parameter MANT_BITS = BITS-EXP_BITS - 1,
	parameter [EXP_BITS-1 : 0] EXP_BIAS = (1'b1 << (EXP_BITS - 1'b1)) - 1'b1
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
	output wire out_ready
);


// multiplier states
typedef enum
{
	Ready,      // start multiplication
	Mult,       // perform the multiplication
	Norm_Over,  // normalise overflowing float
	Norm_Under  // normalise underflowing float
} t_state;

t_state state = Ready, state_next = Ready;


// input values
logic [EXP_BITS-1 : 0] a_exp;
logic [EXP_BITS-1 : 0] b_exp;
logic [MANT_BITS : 0] a_mant;
logic [MANT_BITS : 0] b_mant;

assign a_exp = in_a[BITS-2 : BITS-1-EXP_BITS];
assign b_exp = in_b[BITS-2 : BITS-1-EXP_BITS];
assign a_mant = in_a[MANT_BITS-1 : 0] | (1'b1 << MANT_BITS);
assign b_mant = in_b[MANT_BITS-1 : 0] | (1'b1 << MANT_BITS);


// multiplied values
logic sign;
logic [EXP_BITS-1 : 0] exp, exp_next;
logic [MANT_BITS*2 : 0] mant, mant_next;

wire first_mant_bit;
wire [MANT_BITS-1 : 0] actual_mant;
assign first_mant_bit = mant[MANT_BITS];
assign actual_mant = mant[MANT_BITS-1 : 0];


// output product
assign sign = in_a[BITS-1] ^ in_b[BITS-1];
assign out_prod = { sign, exp, actual_mant};
assign out_ready = (state==Ready ? 1'b1 : 1'b0);


// clock process
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst) begin
		state <= Ready;
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
		Ready:      // start new multiplication
			begin
				// wait for start signal
				if(in_start) begin
					state_next = Mult;
				end
			end

		Mult:       // perform the multiplication
			begin
				// exponent
				exp_next = a_exp + b_exp - EXP_BIAS;

				// mantissa
				mant_next = (a_mant * b_mant) >> MANT_BITS;

				state_next = Norm_Over;
			end

		Norm_Over:  // normalise overflowing float
			begin
				if(mant >= (1'b1 << (MANT_BITS+1'b1))) begin
					mant_next = mant >> 1'b1;
					exp_next = exp + 1'b1;
					state_next = Norm_Over;
				end else begin
					state_next = Norm_Under;
				end
			end

		Norm_Under: // normalise underflowing float
			begin
				//$display("mant = %b, first_bit = %b", mant, first_mant_bit);
				if(actual_mant != 0 && ~first_mant_bit) begin
					mant_next = mant << 1'b1;
					exp_next = exp - 1'b1;
					state_next = Norm_Under;
				end else begin
					state_next = Ready;
				end
			end
	endcase
end

endmodule
