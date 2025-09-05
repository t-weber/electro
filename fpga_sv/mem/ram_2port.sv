/**
 * 2-port ram
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 26-May-2024
 * @license see 'LICENSE' file
 *
 * References:
 *   - Listing 5.24 on pp. 119-120 of the book by Pong P. Chu, 2011, ISBN 978-1-118-00888-1.
 *   - Chapter 7 in: https://docs.xilinx.com/v/u/en-US/xst_v6s6
 */


/**
 * pins for a port
 */
`define PORT_PINS(PORT_NR)  \
	input  wire in_clk_``PORT_NR``,  \
	input  wire in_read_ena_``PORT_NR``, \
	input  wire in_write_ena_``PORT_NR``,  \
	input  wire [ADDR_BITS - 1 : 0] in_addr_``PORT_NR``,  \
	input  wire [WORD_BITS - 1 : 0] in_data_``PORT_NR``,  \
	output wire [WORD_BITS - 1 : 0] out_data_``PORT_NR``


/**
 * process for a port
 */
`define PORT_PROC(PORT_NR)  \
	logic [WORD_BITS - 1 : 0] data_``PORT_NR``;  \
	assign out_data_``PORT_NR`` = data_``PORT_NR``;  \
\
	always@(posedge in_clk_``PORT_NR``)  \
	begin  \
		if(in_rst == 1'b1) begin  \
			data_``PORT_NR`` <= { WORD_BITS{ 1'b0 } };  \
			/*if(PORT_NR == 1'b1) begin*/  \
				/*for(bit [ADDR_BITS : 0] i = 0; i < NUM_WORDS; ++i)*/  \
					/*words[i] <= { WORD_BITS{ 1'b0 } };*/  \
			/*end*/  \
		end else begin  \
			if((ALL_WRITE == 1'b1 || PORT_NR == 1'b1)  \
				&& in_write_ena_``PORT_NR`` == 1'b1  \
				&& in_addr_``PORT_NR`` < NUM_WORDS)  \
				words[in_addr_``PORT_NR``] <= in_data_``PORT_NR``;  \
			if(in_read_ena_``PORT_NR`` == 1'b1 && in_addr_``PORT_NR`` < NUM_WORDS)  \
				data_``PORT_NR`` <= words[in_addr_``PORT_NR``];  \
			else  \
				data_``PORT_NR`` <= { WORD_BITS{ 1'b0 } };  \
		end  \
	end


module ram_2port
#(
	parameter ADDR_BITS = 3,
	parameter WORD_BITS = 8,
	parameter NUM_WORDS = 2**ADDR_BITS,
	parameter ALL_WRITE = 1'b1  // enable write for all ports
)
(
	// reset
	input wire in_rst,

	// port 1
	`PORT_PINS(1)

`ifndef RAM_DISABLE_PORT2
	// port 2
	, `PORT_PINS(2)
`endif
);



`ifdef RAM_UNPACKED
	// memory flip-flops as unpacked array (non-contiguous ram, e.g. list of flip-flops)
	logic [WORD_BITS - 1 : 0] words [0 : NUM_WORDS - 1];
`else
	// memory flip-flops as packed array (contiguous ram)
	logic [0 : NUM_WORDS - 1][WORD_BITS - 1 : 0] words;
`endif

initial begin
	for(bit [ADDR_BITS : 0] i = 0; i < NUM_WORDS; ++i)
		words[i] <= { WORD_BITS{ 1'b1 } };
end


// port 1
`PORT_PROC(1)

`ifndef RAM_DISABLE_PORT2
	// port 2
	`PORT_PROC(2)
`endif


endmodule
