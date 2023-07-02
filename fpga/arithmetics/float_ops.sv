/**
 * float multiplier
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 10-June-2023
 * @license see 'LICENSE' file
 */

module float_ops
#(
	parameter BITS = 32,
	parameter EXP_BITS = 8,
	parameter MANT_BITS = BITS - EXP_BITS - 1,
	parameter [EXP_BITS-1 : 0] EXP_BIAS = (1'b1 << (EXP_BITS - 1'b1)) - 1'b1
)
(
	// clock and reset
	input wire in_clk, in_rst,

	// start signal
	input wire in_start,

	// input operands
	input wire [BITS-1 : 0] in_a, in_b,

	// requested operation:
	//   2'b00 -> multiplication
	//   2'b01 -> division
	//   2'b10 -> addition
	//   2'b11 -> subtraction
	input wire [1 : 0] in_op,

	// output
	output wire [BITS-1 : 0] out_prod,

	// calculation finished?
	output wire out_ready
);


// multiplier states
typedef enum
{
	Ready,      // start multiplication
	Mult,       // perform a multiplication
	Div,        // perform a division
	Add,        // perform an addition
	Sub,        // perform a subtraction
	Norm_Over,  // normalise overflowing float
	Norm_Under  // normalise underflowing float
} t_state;

t_state state = Ready, state_next = Ready;


// input values
logic [EXP_BITS-1 : 0] a_exp, b_exp;
logic [MANT_BITS : 0] a_mant, b_mant;
logic a_sign, b_sign;

assign a_sign = in_a[BITS-1];
assign b_sign = in_b[BITS-1];
assign a_exp = in_a[BITS-2 : BITS-1-EXP_BITS];
assign b_exp = in_b[BITS-2 : BITS-1-EXP_BITS];
assign a_mant = in_a[MANT_BITS-1 : 0] | (1'b1 << MANT_BITS);
assign b_mant = in_b[MANT_BITS-1 : 0] | (1'b1 << MANT_BITS);


// calculated values
logic sign, sign_next;
logic [EXP_BITS-1 : 0] exp, exp_next;
logic [MANT_BITS*2 : 0] mant, mant_next;

logic [MANT_BITS : 0] a_mant_shifted, b_mant_shifted;

wire first_mant_bit;
wire [MANT_BITS-1 : 0] actual_mant;
assign first_mant_bit = mant[MANT_BITS];
assign actual_mant = mant[MANT_BITS-1 : 0];


// output product
assign out_prod = { sign, exp, actual_mant };
assign out_ready = (state==Ready ? 1'b1 : 1'b0);


// clock process
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst) begin
		state <= Ready;
		exp <= 0;
		mant <= 0;
		sign <= 0;
	end

	else if(in_clk) begin
		state <= state_next;
		exp <= exp_next;
		mant <= mant_next;
		sign <= sign_next;
	end
end


// calculation process
always_comb begin
	// save registers
	state_next = state;
	exp_next = exp;
	mant_next = mant;
	sign_next = sign;

	case(state)
		Ready:      // start new multiplication
			begin
				// wait for start signal
				if(in_start) begin
					state_next = t_state'(
						in_op == 2'b00 ? Mult :
						in_op == 2'b01 ? Div :
						in_op == 2'b10 ? Add :
						in_op == 2'b11 ? Sub :
						Ready);
				end
			end

		Mult:       // perform a multiplication
			begin
				exp_next = a_exp + b_exp - EXP_BIAS;
				mant_next = (a_mant * b_mant) >> MANT_BITS;
				sign_next = a_sign ^ b_sign;

				state_next = Norm_Over;
			end

		Div:        // perform a division
			begin
				exp_next = a_exp - EXP_BITS'(MANT_BITS) - b_exp + EXP_BIAS;
				mant_next = ((a_mant << MANT_BITS) / b_mant) << MANT_BITS;
				sign_next = a_sign ^ b_sign;

				state_next = Norm_Over;
			end

		Add:        // perform an addition
			begin
				if(a_exp >= b_exp) begin
					exp_next = a_exp;
					b_mant_shifted = b_mant >> (a_exp - b_exp);

					if(a_sign == b_sign) begin
						mant_next = a_mant + b_mant_shifted;
						sign_next = a_sign;
					end else if(a_sign != b_sign && a_mant >= b_mant_shifted) begin
						mant_next = a_mant - b_mant_shifted;
						sign_next = a_sign;
					end else begin
						mant_next = - a_mant + b_mant_shifted;
						sign_next = b_sign;
					end
				end else begin
					exp_next = b_exp;
					a_mant_shifted = a_mant >> (b_exp - a_exp);

					if(a_sign == b_sign) begin
						mant_next = b_mant + a_mant_shifted;
						sign_next = a_sign;
					end else if(a_sign != b_sign && b_mant >= a_mant_shifted) begin
						mant_next = b_mant - a_mant_shifted;
						sign_next = b_sign;
					end else begin
						mant_next = - b_mant + a_mant_shifted;
						sign_next = a_sign;
					end
				end

				state_next = Norm_Over;
			end

		Sub:        // perform a subtraction
			begin
				if(a_exp >= b_exp) begin
					exp_next = a_exp;
					b_mant_shifted = b_mant >> (a_exp - b_exp);

					if(a_sign == ~b_sign) begin
						mant_next = a_mant + b_mant_shifted;
						sign_next = a_sign;
					end else if(a_sign != ~b_sign && a_mant >= b_mant_shifted) begin
						mant_next = a_mant - b_mant_shifted;
						sign_next = a_sign;
					end else begin
						mant_next = - a_mant + b_mant_shifted;
						sign_next = ~b_sign;
					end
				end else begin
					exp_next = b_exp;
					a_mant_shifted = a_mant >> (b_exp - a_exp);

					if(a_sign == ~b_sign) begin
						mant_next = b_mant + a_mant_shifted;
						sign_next = ~b_sign;
					end else if(a_sign != ~b_sign && b_mant >= a_mant_shifted) begin
						mant_next = b_mant - a_mant_shifted;
						sign_next = ~b_sign;
					end else begin
						mant_next = - b_mant + a_mant_shifted;
						sign_next = a_sign;
					end
				end

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
