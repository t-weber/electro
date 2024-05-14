/**
 * subtractor
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 13-May-2023
 * @license see 'LICENSE' file
 *
 * Reference: https://en.wikipedia.org/wiki/Subtractor
 */

module subtractor
#(
	// selects full or half subtractor
	parameter FULL_SUBTRACTOR = 1
)
(
	input wire in_a, in_b, in_borrow,
	output wire out_diff, out_borrow
);

wire a_xor_b = in_a ^ in_b;
wire not_a_and_b = ~in_a & in_b;

generate
	if(FULL_SUBTRACTOR) begin
		assign out_diff = a_xor_b ^ in_borrow;
		assign out_borrow = not_a_and_b |
			(~in_a & in_borrow) |
			(in_b & in_borrow);
	end
	else begin
		assign out_diff = a_xor_b;
		assign out_borrow = not_a_and_b;
	end
endgenerate

endmodule



module rippleborrowsubtractor
#(
	parameter BITS = 8
)
(
	input wire [BITS-1 : 0] in_a, in_b,
	output wire [BITS-1 : 0] out_diff
);

	wire [BITS-1 : 0] borrow;

	subtractor #(.FULL_SUBTRACTOR(0)) subtractor_0
		(.in_a(in_a[0]), .in_b(in_b[0]),
		.in_borrow(1'b0),
		.out_diff(out_diff[0]),
		.out_borrow(borrow[0]));

	genvar subtractor_idx;
	generate
		for(subtractor_idx=1; subtractor_idx<BITS; ++subtractor_idx) begin : gensubtractors
			subtractor #(.FULL_SUBTRACTOR(1)) subtractor_n
				(.in_a(in_a[subtractor_idx]), .in_b(in_b[subtractor_idx]),
				.in_borrow(borrow[subtractor_idx-1]),
				.out_diff(out_diff[subtractor_idx]),
				.out_borrow(borrow[subtractor_idx]));
		end
	endgenerate

endmodule
