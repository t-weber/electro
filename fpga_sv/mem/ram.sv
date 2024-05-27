/**
 * ram
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 21-February-2024
 * @license see 'LICENSE' file
 *
 * References:
 *   - Listing 5.24 on pp. 119-120 of the book by Pong P. Chu, 2011, ISBN 978-1-118-00888-1.
 *   - Chapter 7 in: https://docs.xilinx.com/v/u/en-US/xst_v6s6
 */


module ram
#(
	parameter NUM_PORTS = 2,
	parameter ADDR_BITS = 3,
	parameter WORD_BITS = 8,
	parameter NUM_WORDS = 2**ADDR_BITS
)
(
	// clock and reset
	input  wire in_clk, in_rst,

	// enable signals
	input  wire [0 : NUM_PORTS - 1] in_read_ena, in_write_ena,

	// address and data
	input  wire [0 : NUM_PORTS - 1][ADDR_BITS - 1 : 0] in_addr,
	input  wire [0 : NUM_PORTS - 1][WORD_BITS - 1 : 0] in_data,
	output wire [0 : NUM_PORTS - 1][WORD_BITS - 1 : 0] out_data
);



`ifdef RAM_UNPACKED
	// memory flip-flops as unpacked array (non-contiguous ram, e.g. list of flip-flops)
	logic [WORD_BITS - 1 : 0] words [0 : NUM_WORDS - 1];
`else
	// memory flip-flops as packed array (contiguous ram)
	logic [0 : NUM_WORDS - 1][WORD_BITS - 1 : 0] words;
		// = { 8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38 };
`endif


// output data register
logic [0 : NUM_PORTS - 1][WORD_BITS - 1 : 0] data;


genvar port_idx;
generate for(port_idx = 0; port_idx < NUM_PORTS; ++port_idx)
begin : gen_ports

	// output data
	assign out_data[port_idx] = data[port_idx];


	always@(posedge in_clk/*, posedge in_rst*/)
	begin
		if(in_rst == 1'b1) begin
			data[port_idx] <= { WORD_BITS{ 1'b0 } };

			// fill ram with zeros
			/*if(port_idx == 0) begin
				for(logic [WORD_BITS : 0] i = 0; i < NUM_WORDS; ++i) begin
					words[i] <= { WORD_BITS{ 1'b0 } };
				end
			end*/
		end

		else begin
			// write data to ram
			// if NUM_WORDS == 2**ADDR_BITS the range check against NUM_WORDS is not needed
			if(in_write_ena == 1'b1 && in_addr[port_idx] < NUM_WORDS) begin
				//$display("write to addr %h", in_addr[port_idx]);
				words[in_addr[port_idx]] <= in_data[port_idx];
			end

			// read data from ram into buffer
			// if NUM_WORDS == 2**ADDR_BITS the range check against NUM_WORDS is not needed
			if(in_read_ena == 1'b1 && in_addr[port_idx] < NUM_WORDS) begin
				data[port_idx] <= words[in_addr[port_idx]];
			end else begin
				data[port_idx] <= { WORD_BITS{ 1'b0 } };
			end
		end
	end
end
endgenerate

endmodule
