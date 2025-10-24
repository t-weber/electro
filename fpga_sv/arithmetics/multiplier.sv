/**
 * multiplier
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 1-May-2023
 * @license see 'LICENSE' file
 */

//`define MULT_USE_OWN_ADDER


module multiplier
#(
	parameter IN_BITS  = 8,
	parameter OUT_BITS = 8
)
(
	// clock and reset
	input wire in_clk, in_rst,

	// start signal
	input wire in_start,

	// inputs
	input wire [IN_BITS - 1 : 0] in_a, in_b,

	// output
	output wire [OUT_BITS - 1 : 0] out_prod,

	// calculation finished?
	output wire out_finished
);


// multiplier states
typedef enum
{
	Reset,      // start multiplication
	CheckShift, // check if the current bit in a is 1 
	Add,        // if so, shift b to the current bit index
              // and add the shifted value to the product
	NextBit,    // next bit
	Finished    // multiplication finished
} t_state;

t_state state = Reset, state_next = Reset;


logic [OUT_BITS - 1 : 0] prod, prod_next;       // current product value
wire [OUT_BITS - 1 : 0] b_shifted;              // shifted b_value
logic [OUT_BITS - 1 : 0] b_sum;                 // prod * b_shifted
bit [$clog2(IN_BITS) : 0] bitidx, bitidx_next;  // in_a bit index (range 0 to IN_BITS-1)

assign b_shifted = (in_b <<< bitidx);


`ifdef MULT_USE_OWN_ADDER
	// use own adder module
	// add shifted b value to current product value
	ripplecarryadder #(.BITS(OUT_BITS)) sum(
		.in_a(prod), .in_b(b_shifted), .out_sum(b_sum));
`endif


// output signals
assign out_prod = prod;
assign out_finished = (state==Finished ? 1'b1 : 1'b0);


// clock process
always_ff@(posedge in_clk/*, posedge in_rst*/) begin
	if(in_rst) begin
		state <= Reset;
		prod <= 1'b0;
		bitidx <= 1'b0;
	end

	else /*if(in_clk)*/ begin
		state <= state_next;
		prod <= prod_next;
		bitidx <= bitidx_next;
	end
end


// calculation process
always_comb begin
	// save registers
	state_next = state;
	prod_next = prod;
	bitidx_next = bitidx;

	unique case(state)
		Reset:
			begin
				prod_next = 1'b0;
				bitidx_next = 1'b0;
				if(in_start)  // wait for start signal
					state_next = CheckShift;
			end

		CheckShift:
			begin
				if(in_a[bitidx])
					state_next = Add;
				else
					state_next = NextBit;
			end

		Add:
			begin
`ifdef MULT_USE_OWN_ADDER
				// alternatively use adder module
				prod_next = b_sum;
`else
				// use internal adder
				prod_next = prod + b_shifted;
`endif

				state_next = NextBit;
			end

		NextBit:
			begin
				//$display("bitidx = %d", bitidx);
				if(bitidx == IN_BITS-1) begin
					state_next = Finished;
				end else begin
					bitidx_next = bitidx + 1'b1;
					state_next = CheckShift;
				end
			end

		Finished:
			begin
				// wait for next start signal
				if(in_start)
					state_next = Reset;
			end

		default:
			begin
				state_next = Reset;
			end
	endcase

`ifdef __IN_SIMULATION__
	$display("*** multiplier: %s, seg=%d, init=%d, dat=%d. ***",
		state.name(), b_sum, b_shifted, prod);
`endif

end

endmodule
