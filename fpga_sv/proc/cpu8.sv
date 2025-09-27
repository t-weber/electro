/**
 * 8-bit cpu
 * @author Tobias Weber <tobias.weber@tum.de> (0000-0002-7230-1932)
 * @date September-2025
 * @license see 'LICENSE' file
 */

/**
 * special registers
 * -----------------
 * - register 0 is the program counter
 * - register 3 doubles as status register
 *
 * 0-register opcodes with immediate value
 * ---------------------------------------
 * 00_1_00000
 *
 * 0-register opcodes without immediate value
 * ------------------------------------------
 * 00_0_00000        halt
 * 00_0_00001        nop
 *
 * 1-register opcodes with immediate value
 * ---------------------------------------
 * 01_1_000_aa val   transfer immediate val to register aa
 * 01_1_001_aa addr  transfer mem[addr] to register aa
 * 01_1_010_aa addr  transfer register aa to mem[addr]
 *
 * 1-register opcodes without immediate value
 * ------------------------------------------
 * 01_0_100_aa       bit-wise not of register aa
 * 01_0_101_aa       logical not of register aa
 *
 * 2-register opcodes
 * ------------------
 * 1_000_aa_bb      register transfer aa -> bb
 * 1_001_aa_bb      aa += bb
 * 1_010_aa_bb      aa -= bb
 * 1_011_aa_bb      aa <<= bb
 * 1_100_aa_bb      aa >>= bb
 * 1_101_aa_bb      reg[3] = compare(aa, bb)
 * 1_110_aa_bb      aa &= bb
 * 1_111_aa_bb      aa |= bb
 */

module cpu8
#(
	parameter ADDR_BITS = 8,
	parameter WORD_BITS = 8
)
(
	input wire in_clk, in_rst,

	// memory interface
	input wire in_mem_ready,
	input wire [WORD_BITS - 1 : 0] in_mem_data,

	output wire out_mem_ready, out_mem_write,
	output wire [WORD_BITS - 1 : 0] out_mem_data,
	output wire [ADDR_BITS - 1 : 0] out_mem_addr,

	// debugging
	output wire [WORD_BITS - 1 : 0] out_instr
);


// ----------------------------------------------------------------------------
// registers
// ----------------------------------------------------------------------------
localparam NUM_REGS = WORD_BITS/2;
localparam REG_BITS = $clog2(NUM_REGS);

// special register indices
localparam pc_idx     = 0;
localparam status_idx = 3;

localparam immval_bit = WORD_BITS - 3;


reg [WORD_BITS - 1 : 0] instr, next_instr;       // current instruction
reg [ADDR_BITS - 1 : 0] mem_addr, next_mem_addr; // current address
reg mem_ready, next_mem_ready;                   // request memory read or write
reg mem_write, next_mem_write;                   // request memory write
reg [WORD_BITS - 1 : 0] mem_data, next_mem_data; // data to write to memory

reg [0 : NUM_REGS - 1][WORD_BITS - 1 : 0] regs, next_regs;  // registers
reg [REG_BITS - 1 : 0] regidx1, next_regidx1;    // register index 1
reg [REG_BITS - 1 : 0] regidx2, next_regidx2;    // register index 2
reg [WORD_BITS - 1 : 0] immval, next_immval;     // immediate value

reg is_1addr, next_is_1addr;
reg is_2addr, next_is_2addr;
reg has_immval, next_has_immval;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// outputs
// ----------------------------------------------------------------------------
assign out_mem_addr = mem_addr;
assign out_instr = instr;

assign out_mem_ready = mem_ready;
assign out_mem_write = mem_write;
assign out_mem_data = mem_data;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// cpu cycle
// see: https://en.wikipedia.org/wiki/Instruction_cycle
// see: https://en.wikipedia.org/wiki/Classic_RISC_pipeline
// ----------------------------------------------------------------------------
typedef enum bit[2 : 0]
{
	FETCH, DECODE, EXEC,
	LOAD_IMMVAL, WRITE_MEM,
	HALT
} t_cycle;

t_cycle cycle = FETCH, next_cycle = FETCH;
bit [1 : 0] subcycle = 1'b0, next_subcycle = 1'b0;


always_ff@(posedge in_clk) begin
	if(in_rst) begin
		cycle <= FETCH;
		subcycle <= 1'b0;

		instr <= 1'b0;
		mem_addr <= 1'b0;
		mem_ready <= 1'b0;
		mem_write <= 1'b0;
		mem_data <= 1'b0;

		regs <= 1'b0;
		regidx1 <= 1'b0;
		regidx2 <= 1'b0;
		immval <= 1'b0;

		is_1addr <= 1'b0;
		is_2addr <= 1'b0;
		has_immval <= 1'b0;
	end else begin
		cycle <= next_cycle;
		subcycle <= next_subcycle;

		instr <= next_instr;
		mem_addr <= next_mem_addr;
		mem_ready <= next_mem_ready;
		mem_write <= next_mem_write;
		mem_data <= next_mem_data;

		regs <= next_regs;
		regidx1 <= next_regidx1;
		regidx2 <= next_regidx2;
		immval <= next_immval;

		is_1addr <= next_is_1addr;
		is_2addr <= next_is_2addr;
		has_immval <= next_has_immval;
	end
end


always_comb begin
	next_cycle = cycle;
	next_subcycle = subcycle;

	next_instr = instr;
	next_mem_addr = mem_addr;
	next_mem_ready = 1'b0; //mem_ready;
	next_mem_write = mem_write;
	next_mem_data = mem_data;

	next_regs = regs;
	next_regidx1 = regidx1;
	next_regidx2 = regidx2;
	next_immval = immval;

	next_is_1addr = is_1addr;
	next_is_2addr = is_2addr;
	next_has_immval = has_immval;

	unique case(cycle)
		FETCH: begin
			unique case(subcycle)
				0: begin  // request new instruction at pc
					next_mem_addr = regs[pc_idx];
					next_regs[pc_idx] = regs[pc_idx] + 1'b1;
					next_mem_ready = 1'b1;
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
			next_is_1addr = 1'b0;
			next_is_2addr = 1'b0;
			next_has_immval = 1'b0;
			next_cycle = EXEC;

			if(instr[WORD_BITS - 1] == 1'b1) begin
				// 2-register opcode
				next_is_2addr = 1'b1;
				next_regidx1 = instr[WORD_BITS/2 - 1 -: REG_BITS];
				next_regidx2 = instr[WORD_BITS/2 - 1 - REG_BITS : 0];
			end
			else if(instr[WORD_BITS - 1 -: 2] == 2'b01) begin
				// 1-register opcode
				next_is_1addr = 1'b1;
				next_regidx1 = instr[0 +: REG_BITS];

				// does the instruction have an immediate value in the following word?
				if(instr[immval_bit] == 1'b1) begin
					next_has_immval = 1'b1;
					next_cycle = LOAD_IMMVAL;
				end
			end
			else if(instr[WORD_BITS - 1 -: 2] == 2'b00) begin
				// 0-register opcode
				// does the instruction have an immediate value in the following word?
				if(instr[immval_bit] == 1'b1) begin
					next_has_immval = 1'b1;
					next_cycle = LOAD_IMMVAL;
				end
			end
		end

		LOAD_IMMVAL: begin
			// load immediate word following pc
			unique case(subcycle)
				0: begin  // request immediate value
					next_mem_addr = regs[pc_idx];
					next_regs[pc_idx] = regs[pc_idx] + 1'b1;
					next_mem_ready = 1'b1;
					next_subcycle = 1;
				end
				1: begin  // fetch immediate value
					if(in_mem_ready) begin
						next_immval = in_mem_data;
						next_cycle = EXEC;
						next_subcycle = 0;
					end
				end
			endcase
		end

		WRITE_MEM: begin
			unique case(subcycle)
				0: begin  // request memory write
					next_mem_ready = 1'b1;
					next_mem_write = 1'b1;
					next_subcycle = 1;
				end
				1: begin  // wait for writing done
					next_mem_ready = 1'b1;
					next_mem_write = 1'b1;
					if(in_mem_ready) begin
						next_mem_ready = 1'b0;
						next_mem_write = 1'b0;
						next_cycle = FETCH;
						next_subcycle = 0;
					end
				end
			endcase
		end

		EXEC: begin
			// -------------------------------------------------------------------------
			// 2-register instructions
			// -------------------------------------------------------------------------
			if(is_2addr) begin
				if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b000) begin
					// register transfer
					next_regs[regidx2] = regs[regidx1];
					next_cycle = FETCH;
				end
				else if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b001) begin
					// reg1 += reg2
					next_regs[regidx1] = regs[regidx1] + regs[regidx2];
					next_cycle = FETCH;
				end
				else if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b010) begin
					// reg1 -= reg2
					next_regs[regidx1] = regs[regidx1] - regs[regidx2];
					next_cycle = FETCH;
				end
				else if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b011) begin
					// reg1 <<= reg2
					next_regs[regidx1] = regs[regidx1] << regs[regidx2];
					next_cycle = FETCH;
				end
				else if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b100) begin
					// reg1 >>= reg2
					next_regs[regidx1] = regs[regidx1] >> regs[regidx2];
					next_cycle = FETCH;
				end
				else if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b101) begin
					// compare(reg1, reg2)
					next_regs[status_idx] = {
						2'b0,
						regs[regidx1] == regs[regidx2],  // 5
						regs[regidx1] != regs[regidx2],  // 4
						regs[regidx1] < regs[regidx2],   // 3
						regs[regidx1] <= regs[regidx2],  // 2
						regs[regidx1] > regs[regidx2],   // 1
						regs[regidx1] >= regs[regidx2]   // 0
					};
					next_cycle = FETCH;
				end
				else if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b110) begin
					// reg1 &= reg2
					next_regs[regidx1] = regs[regidx1] & regs[regidx2];
					next_cycle = FETCH;
				end
				else if(instr[WORD_BITS - 2 : WORD_BITS/2] == 3'b111) begin
					// reg1 |= reg2
					next_regs[regidx1] = regs[regidx1] | regs[regidx2];
					next_cycle = FETCH;
				end
			end
			// -------------------------------------------------------------------------

			// -------------------------------------------------------------------------
			// 1-register instructions with immediate value
			// -------------------------------------------------------------------------
			else if(is_1addr && has_immval) begin
				if(instr[WORD_BITS - 4 : REG_BITS] == 3'b000) begin
					// transfer immediate value to register
					next_regs[regidx1] = immval;
					next_cycle = FETCH;
				end

				else if(instr[WORD_BITS - 4 : REG_BITS] == 3'b001) begin
					// transfer memory to register
					unique case(subcycle)
						0: begin  // request memory word pointed to by immval
							next_mem_addr = immval;
							next_mem_ready = 1'b1;
							next_subcycle = 1;
					end
						1: begin  // fetch memory word
							if(in_mem_ready) begin
								next_regs[regidx1] = in_mem_data;
								next_cycle = FETCH;
								next_subcycle = 0;
							end
						end
					endcase
				end

				else if(instr[WORD_BITS - 4 : REG_BITS] == 3'b010) begin
					// transfer register to memory
					next_mem_addr = immval;
					next_mem_data = regs[regidx1];
					next_cycle = WRITE_MEM;
				end
			end  // is_1addr && has_immval
			// -------------------------------------------------------------------------

			// -------------------------------------------------------------------------
			// 1-register instructions without immediate value
			// -------------------------------------------------------------------------
			else if(is_1addr && !has_immval) begin
				if(instr[WORD_BITS - 4 : REG_BITS] == 3'b100) begin
					// bit-wise not of register
					next_regs[regidx1] = ~regs[regidx1];
					next_cycle = FETCH;
				end

				else if(instr[WORD_BITS - 4 : REG_BITS] == 3'b101) begin
					// logical not of register
					next_regs[regidx1] = !regs[regidx1];
					next_cycle = FETCH;
				end
			end  // is_1addr && !has_immval
			// -------------------------------------------------------------------------

			// -------------------------------------------------------------------------
			// 0-register instructions with immediate value
			// -------------------------------------------------------------------------
			else if(!is_1addr && !is_2addr && has_immval) begin
			end  // !is_1addr && !is_2addr && has_immval
			// -------------------------------------------------------------------------
	
			// -------------------------------------------------------------------------
			// 0-register instructions without immediate value
			// -------------------------------------------------------------------------
			else if(!is_1addr && !is_2addr && !has_immval) begin
				if(instr[WORD_BITS - 3 : 0] == 5'b00000) begin
					// halt
					next_cycle = HALT;
				end
				else if(instr[WORD_BITS - 3 : 0] == 5'b00001) begin
					// nop
					next_cycle = FETCH;
				end
			end  // !is_1addr && !is_2addr && !has_immval
			// -------------------------------------------------------------------------

		end  // EXEC
		
		HALT: begin
		end
	endcase
end
// ----------------------------------------------------------------------------


endmodule
