/**
 * adder
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 30-April-2023
 * @license see 'LICENSE' file
 *
 * Reference: https://en.wikipedia.org/wiki/Adder_(electronics)
 */

module adder
#(
	// selects full or half adder
	parameter FULL_ADDER = 1
)
(
	input wire in_a, in_b, in_carry,
	output wire out_sum, out_carry
);

wire a_xor_b = in_a ^ in_b;
wire a_and_b = in_a & in_b;

generate
	if(FULL_ADDER) begin
		wire x_and_c = a_xor_b & in_carry;

		assign out_sum = a_xor_b ^ in_carry;
		assign out_carry = a_and_b | x_and_c;
	end
	else begin
		assign out_sum = a_xor_b;
		assign out_carry = a_and_b;
	end
endgenerate

endmodule



module ripplecarryadder
#(
	parameter BITS = 8
)
(
	input wire [BITS-1 : 0] in_a, in_b,
	output wire [BITS-1 : 0] out_sum
);

	wire [BITS-1 : 0] carry;

	adder #(.FULL_ADDER(0)) adder_0
		(.in_a(in_a[0]), .in_b(in_b[0]),
		.in_carry(1'b0),
		.out_sum(out_sum[0]), .out_carry(carry[0]));

	genvar adder_idx;
	generate
		for(adder_idx=1; adder_idx<BITS; ++adder_idx) begin : genadders
			adder #(.FULL_ADDER(1)) addr_n
				(.in_a(in_a[adder_idx]), .in_b(in_b[adder_idx]),
				.in_carry(carry[adder_idx-1]),
				.out_sum(out_sum[adder_idx]), .out_carry(carry[adder_idx]));
		end
	endgenerate

endmodule
