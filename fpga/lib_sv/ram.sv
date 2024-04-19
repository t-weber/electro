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
	input  wire [NUM_PORTS] in_read_ena, in_write_ena,

	// address and data
	input  wire [NUM_PORTS][ADDR_BITS-1 : 0] in_addr,
	input  wire [NUM_PORTS][WORD_BITS-1 : 0] in_data,
	output wire [NUM_PORTS][WORD_BITS-1 : 0] out_data
);



// memory flip-flops
logic [NUM_WORDS][WORD_BITS-1 : 0] words;
	//= { 8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38 };

// output data register
logic [NUM_PORTS][WORD_BITS-1 : 0] data;


genvar port_idx;
generate for(port_idx=0; port_idx<NUM_PORTS; ++port_idx)
begin : gen_ports

	// output data if the output enable signal is 1
	assign out_data[port_idx] = data[port_idx];
	/*assign out_data[port_idx][WORD_BITS-1 : 0] =
		in_read_ena[port_idx]
			? data[port_idx][WORD_BITS-1 : 0]
			: {WORD_BITS{1'bz}};*/


	always@(posedge in_clk, posedge in_rst)
	begin
		if(in_rst == 1) begin
			// fill ram with zeros
			for(logic [WORD_BITS : 0] i=0; i<NUM_WORDS; ++i) begin
				words[i] <= {WORD_BITS{1'b0}};
			end
		end

		else if(in_clk == 1) begin
			// write data to ram
			if(in_write_ena == 1) begin
				//$display("write to addr %h", in_addr[port_idx]);
				words[in_addr[port_idx]] <= in_data[port_idx];
			end

			// read data from ram into buffer
			if(in_read_ena == 1) begin
				data[port_idx] <= words[in_addr[port_idx]];
			end else begin
				data[port_idx] <= {WORD_BITS{1'b0}};
			end
		end
	end
end
endgenerate

endmodule
