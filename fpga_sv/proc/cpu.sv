/**
 * cpu
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date September-2025
 * @license see 'LICENSE' file
 */

module cpu
#(
	parameter ADDR_BITS = 8,
	parameter WORD_BITS = 8
)
(
	input wire in_clk, in_rst,

	// memory interface
	input wire in_mem_ready,
	input wire [WORD_BITS - 1 : 0] in_mem_data,
	output wire out_mem_ready,
	output wire [WORD_BITS - 1 : 0] out_mem_data,
	output wire [ADDR_BITS - 1 : 0] out_mem_addr,

	// debugging
	output wire [WORD_BITS - 1 : 0] out_instr
);


// ----------------------------------------------------------------------------
// registers
// ----------------------------------------------------------------------------
reg [ADDR_BITS - 1 : 0] pc, next_pc;             // program counter
reg [WORD_BITS - 1 : 0] instr, next_instr;       // current instruction
reg [ADDR_BITS - 1 : 0] mem_addr, next_mem_addr; // current address

assign out_mem_addr = mem_addr;
assign out_instr = instr;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// cpu cylce
// see: https://en.wikipedia.org/wiki/Instruction_cycle
// see: https://en.wikipedia.org/wiki/Classic_RISC_pipeline
// ----------------------------------------------------------------------------
typedef enum bit[1 : 0]
{
	FETCH, DECODE, EXEC
} t_cycle;

t_cycle cycle = FETCH, next_cycle = FETCH;
bit [1 : 0] subcycle = 1'b0, next_subcycle = 1'b0;


always_ff@(posedge in_clk) begin
	if(in_rst) begin
		cycle <= FETCH;
		subcycle <= 1'b0;

		pc <= 1'b0;
		instr <= 1'b0;
		mem_addr <= 1'b0;
	end else begin
		cycle <= next_cycle;
		subcycle <= next_subcycle;

		pc <= next_pc;
		instr <= next_instr;
		mem_addr <= next_mem_addr;
	end
end


always_comb begin
	next_cycle = cycle;
	next_subcycle = subcycle;

	next_pc = pc;
	next_instr = instr;
	next_mem_addr = mem_addr;

	unique case(cycle)
		FETCH: begin
			unique case(subcycle)
				0: begin  // request new instruction at pc
					next_mem_addr = pc;
					next_pc = pc + 1'b1;
					next_subcycle = 1;
				end
				1: begin  // fetch new instruction
					if(in_mem_ready) begin
						next_instr = in_mem_data;
						next_cycle = DECODE;
						next_subcycle = 0;
					end
				end
			endcase
		end

		DECODE: begin
		end

		EXEC: begin
		end
	endcase
end
// ----------------------------------------------------------------------------


endmodule
