/**
 * bcd conversion
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 19-April-2023
 * @license see 'LICENSE' file
 *
 * @see https://en.wikipedia.org/wiki/Double_dabble
 */

module bcd
#(
	parameter IN_BITS = 8,
	parameter OUT_BITS = 3*4,
	parameter NUM_BCD_DIGITS = OUT_BITS/4
)
(
	// clock and reset
	input wire in_clk,
	input wire in_rst,

	// start signal
	input wire in_start,

	// input
	input wire [IN_BITS-1 : 0] in_num,

	// output
	output wire [OUT_BITS-1 : 0] out_bcd,

	// conversion finished (or idle)?
	output wire out_finished
);


typedef enum bit [2:0] { Idle, Reset, Shift, Add, NextIndex } t_state;

t_state state = Shift;
t_state state_next = Shift;


reg [OUT_BITS-1 : 0] bcdnum, bcdnum_next;
reg [IN_BITS-1 : 0] bitidx, bitidx_next;
reg [NUM_BCD_DIGITS-1 : 0] bcdidx, bcdidx_next;


// output
assign out_bcd = bcdnum;
assign out_finished = (state==Idle ? 1'b1 : 1'b0);


// clock process
always_ff@(posedge in_clk, posedge in_rst) begin
	if(in_rst == 1) begin
		state <= Shift;
		bcdnum <= 0;
		bitidx <= IN_BITS[IN_BITS-1 : 0] - 1'b1;
		bcdidx <= NUM_BCD_DIGITS[NUM_BCD_DIGITS-1 : 0] - 1'b1;
	end

	else if(in_clk == 1) begin
		state <= state_next;
		bcdnum <= bcdnum_next;
		bitidx <= bitidx_next;
		bcdidx <= bcdidx_next;
	end
end


// conversion process
//always@(state, bitidx, bcdidx, bcdnum, in_start, in_num) begin
always_comb begin
	// save registers
	state_next = state;
	bcdnum_next = bcdnum;
	bitidx_next = bitidx;
	bcdidx_next = bcdidx;

	case(state)
		// wait for the start signal
		Idle:
			if(in_start == 1) begin
				state_next = Reset;
			end

		// reset
		Reset:
			begin
				bcdnum_next = 0;
				bitidx_next = IN_BITS[IN_BITS-1 : 0] - 1'b1;
				bcdidx_next = NUM_BCD_DIGITS[NUM_BCD_DIGITS-1 : 0] - 1'b1;
				state_next = Shift;
			end

		// shift left
		Shift:
			begin
				bcdnum_next[OUT_BITS-1 : 1] = bcdnum[OUT_BITS-2 : 0];
				bcdnum_next[0] = in_num[bitidx];

				// no addition for last index
				if(bitidx != 0)
					state_next = Add;
				else
					state_next = Idle;
			end

		// add 3 if bcd digit >= 5
		Add:
			begin
				// check if the bcd digit is >= 5, if so, add 3
				if(bcdnum[bcdidx*4+3 -: 4] >= 5)
					bcdnum_next = bcdnum + (2'd3 << (bcdidx*3'd4));

				if(bcdidx != 0)
					bcdidx_next = bcdidx - 1'b1;
				else begin
					bcdidx_next = NUM_BCD_DIGITS[NUM_BCD_DIGITS-1 : 0] - 1'b1;
					state_next = NextIndex;
				end
			end

		// next bit
		NextIndex:
			begin
				bitidx_next = bitidx - 1'b1;
				state_next = Shift;
			end
	endcase
end


endmodule
