/**
 * 16-bit cpu
 * @author Tobias Weber <tobias.weber@tum.de> (0000-0002-7230-1932)
 * @date October-2025
 * @license see 'LICENSE' file
 */

//`define CPU16_DEDICATED_IP  // use dedicated register for program counter
//define CPU_NO_MULT_DIV  // don't use arithmetics modules


/**
 * special registers
 * -----------------
 * - register c is the instruction pointer
 * - register d is the stack pointer
 * - register e is the base pointer
 * - register f is the status register
 *
 *
 * 0-register opcodes with immediate value
 * ---------------------------------------
 * 00_1_00000 0000_0000       TODO
 *
 * 0-register opcodes without immediate value
 * ------------------------------------------
 * 00_0_00000 0000_0000       halt
 * 00_0_00000 0000_0001       nop
 * 00_0_00000 0000_0010       return from function
 * 00_0_00000 0000_0011       return from interrupt service routine
 *
 * 00_0_00000 0000_0100       equal? (call compare before)
 * 00_0_00000 0000_0101       not equal? (call compare before)
 * 00_0_00000 0000_0110       greater? (call compare before)
 * 00_0_00000 0000_0111       greater or equal? (call compare before)
 * 00_0_00000 0000_1000       less? (call compare before)
 * 00_0_00000 0000_1001       less or equal? (call compare before)
 *
 * 00_0_00000 0001_0000       write active irq number into status register
 *
 *
 * 1-register opcodes with immediate value
 * ---------------------------------------
 * 01_1_000000000_aaaa val    transfer immediate value to register aaaa
 * 01_1_000000001_aaaa addr   transfer mem[addr] to register aaaa
 * 01_1_000000010_aaaa addr   transfer register aaaa to mem[addr]
 *
 * 1-register opcodes without immediate value
 * ------------------------------------------
 * 01_0_000000000_aaaa        jump to absolute address in register aaaa if status_reg[0]
 * 01_0_000000001_aaaa        jump to absolute address in register aaaa
 * 01_0_000000010_aaaa        jump to relative address in register aaaa
 * 01_0_000000011_aaaa        call function at absolute address in register aaaa
 *
 * 01_0_000000100_aaaa        bit-wise not of register aaaa
 * 01_0_000000101_aaaa        logical not of register aaaa
 *
 * 01_0_000000110_aaaa        push register aaaa on stack
 * 01_0_000000111_aaaa        pop register aaaa from stack
 *
 * 01_0_000001000_aaaa        aaaa <<= 1
 * 01_0_000001001_aaaa        aaaa >>= 1
 * 01_0_000001010_aaaa        aaaa = rol(aaaa, 1)
 * 01_0_000001011_aaaa        aaaa = ror(aaaa, 1)
 *
 *
 * 2-register opcodes
 * ------------------
 * 1_0000000 aaaa_bbbb        register transfer aaaa -> bbbb
 * 1_0000001 aaaa_bbbb        aaaa += bbbb
 * 1_0000010 aaaa_bbbb        aaaa -= bbbb
 * 1_0000011 aaaa_bbbb        aaaa <<= bbbb
 * 1_0000100 aaaa_bbbb        aaaa >>= bbbb
 * 1_0000101 aaaa_bbbb        reg[3] = compare(aaaa, bbbb)
 * 1_0000110 aaaa_bbbb        aaaa &= bbbb
 * 1_0000111 aaaa_bbbb        aaaa |= bbbb
 * 1_0001000 aaaa_bbbb        aaaa *= bbbb
 * 1_0001001 aaaa_bbbb        aaaa /= bbbb
 * 1_0001010 aaaa_bbbb        aaaa %= bbbb
 * 1_0001011 aaaa_bbbb        aaaa = rol(aaaa, bbbb) TODO
 * 1_0001100 aaaa_bbbb        aaaa = ror(aaaa, bbbb) TODO
 */

module cpu16
#(
	parameter ADDR_BITS    = 16,
	parameter WORD_BITS    = 16,

	parameter ENTRY_ADDR   = 0,    // entry point
	parameter ISR_ADDR     = 128,  // entry point of the isr

	parameter SKIP_OP_BITS = 3     // reserved bits in opcode
)
(
	input wire in_clk, in_rst,

	// memory interface
	input wire in_mem_ready,
	input wire [WORD_BITS - 1 : 0] in_mem_data,

	output wire out_mem_ready, out_mem_write,
	output wire [WORD_BITS - 1 : 0] out_mem_data,
	output wire [ADDR_BITS - 1 : 0] out_mem_addr,

	// interrupt lines
	input wire [WORD_BITS - 1 : 0] in_irq,

	// debugging
	output wire [WORD_BITS - 1 : 0] out_instr,  // current instruction
	output wire [ADDR_BITS - 1 : 0] out_pc      // current instruction pointer
);


// ----------------------------------------------------------------------------
// arithmetics
// ----------------------------------------------------------------------------
logic mult_start, next_mult_start = 1'b0;
logic div_start, next_div_start = 1'b0;
wire mult_finished, div_finished;
logic [WORD_BITS - 1 : 0] calc_a, calc_b, next_calc_a, next_calc_b;
wire [WORD_BITS - 1 : 0] mult_prod, div_quot, div_rem;


`ifndef CPU_NO_MULT_DIV

multiplier #(.IN_BITS(WORD_BITS), .OUT_BITS(WORD_BITS))
	mult_mod(.in_clk(in_clk), .in_rst(in_rst),
		.in_a(calc_a), .in_b(calc_b), .in_start(mult_start),
		.out_finished(mult_finished), .out_prod(mult_prod)
);

divider #(.BITS(WORD_BITS))
	div_mod(.in_clk(in_clk), .in_rst(in_rst),
		.in_a(calc_a), .in_b(calc_b), .in_start(div_start),
		.out_finished(div_finished),
		.out_quot(div_quot), .out_rem(div_rem)
);

`endif
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// registers
// ----------------------------------------------------------------------------
localparam NUM_REGS   = 16; //WORD_BITS/2;
localparam REG_BITS   = $clog2(NUM_REGS);

// special register indices
localparam ip_idx     = 12;
localparam sp_idx     = 13;
localparam bp_idx     = 14;
localparam status_idx = 15;

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


`ifdef CPU16_DEDICATED_IP
	reg [ADDR_BITS - 1 : 0] pc = ENTRY_ADDR, next_pc = ENTRY_ADDR;  // program counter

	`define ASSIGN_PC(val) pc <= val
	`define ASSIGN_NEXT_PC(val) next_pc = val

`else

	wire [ADDR_BITS - 1 : 0] pc;
	assign pc = regs[ip_idx];

	`define ASSIGN_PC(val) regs[ip_idx] <= val
	`define ASSIGN_NEXT_PC(val) next_regs[ip_idx] = val

	//`define pc      regs[ip_idx];
	//`define next_pc next_regs[ip_idx];
`endif

reg is_1addr, next_is_1addr;
reg is_2addr, next_is_2addr;
reg has_immval, next_has_immval;

wire [WORD_BITS - 1 : 0] reg1, reg2;
assign reg1 = regs[regidx1];
assign reg2 = regs[regidx2];
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// interrupt handling
// ----------------------------------------------------------------------------
reg irq_handling, next_irq_handling;    // is an irq` currently being handled?
reg [WORD_BITS - 1 : 0] irq, next_irq;  // number of active irq


wire irq_active = |in_irq;
logic irq_active_edge;

logic irq_needs_handling, next_irq_needs_handling;


// get the rising edge of the interrupt signal
edgedet #(.POS_EDGE(1'b1))
	edgedet_mod(
	.in_clk(in_clk), .in_rst(in_rst),
	.in_signal(irq_active), .out_edge(irq_active_edge)
);


always_ff@(posedge in_clk) begin
	if(in_rst) begin
		irq <= 1'b0;
		irq_needs_handling <= 1'b0;

	end else begin
		irq <= next_irq;
		irq_needs_handling <= next_irq_needs_handling;
	end
end


always_comb begin
	next_irq = irq;
	next_irq_needs_handling = irq_needs_handling;

	// accept irq on rising edge if not already handling another
	if(irq_active_edge == 1'b1 && irq_handling == 1'b0) begin
		next_irq = in_irq;
		next_irq_needs_handling = 1'b1;
	end

	else if(irq_handling == 1'b1)
		next_irq_needs_handling = 1'b0;
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// outputs
// ----------------------------------------------------------------------------
assign out_mem_addr = mem_addr;
assign out_instr = instr;
assign out_pc = pc;

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
	IRQ_SAVE_REGS, IRQ_EXEC,
	HALT
} t_cycle;

t_cycle cycle = FETCH, next_cycle = FETCH;
t_cycle cycle_after_write = FETCH, next_cycle_after_write = FETCH;
bit [0 : 0] subcycle = 1'b0, next_subcycle = 1'b0;
bit [1 : 0] subcycle2 = 1'b0, next_subcycle2 = 1'b0;


always_ff@(posedge in_clk) begin
	if(in_rst) begin
		cycle <= FETCH;
		cycle_after_write <= FETCH;
		subcycle <= 1'b0;
		subcycle2 <= 1'b0;

		instr <= 1'b0;
		mem_addr <= 1'b0;
		mem_ready <= 1'b0;
		mem_write <= 1'b0;
		mem_data <= 1'b0;

		regs <= 1'b0;
		regidx1 <= 1'b0;
		regidx2 <= 1'b0;
		immval <= 1'b0;
		`ASSIGN_PC(ENTRY_ADDR);

		is_1addr <= 1'b0;
		is_2addr <= 1'b0;
		has_immval <= 1'b0;

		irq_handling <= 1'b0;

		mult_start <= 1'b0;
		div_start <= 1'b0;
		calc_a <= 1'b0;
		calc_b <= 1'b0;

	end else begin
		cycle <= next_cycle;
		cycle_after_write <= next_cycle_after_write;
		subcycle <= next_subcycle;
		subcycle2 <= next_subcycle2;

		instr <= next_instr;
		mem_addr <= next_mem_addr;
		mem_ready <= next_mem_ready;
		mem_write <= next_mem_write;
		mem_data <= next_mem_data;

		regs <= next_regs;
		regidx1 <= next_regidx1;
		regidx2 <= next_regidx2;
		immval <= next_immval;
`ifdef CPU16_DEDICATED_IP
		pc <= next_pc;
`endif

		is_1addr <= next_is_1addr;
		is_2addr <= next_is_2addr;
		has_immval <= next_has_immval;

		irq_handling <= next_irq_handling;

		mult_start <= next_mult_start;
		div_start <= next_div_start;
		calc_a <= next_calc_a;
		calc_b <= next_calc_b;
	end
end


always_comb begin
	next_cycle = cycle;
	next_cycle_after_write = cycle_after_write;
	next_subcycle = subcycle;
	next_subcycle2 = subcycle2;

	next_instr = instr;
	next_mem_addr = mem_addr;
	next_mem_ready = 1'b0; //mem_ready;
	next_mem_write = mem_write;
	next_mem_data = mem_data;

`ifdef CPU16_DEDICATED_IP
	next_pc = pc;
`endif
	next_regs = regs;
	next_regidx1 = regidx1;
	next_regidx2 = regidx2;
	next_immval = immval;

	next_is_1addr = is_1addr;
	next_is_2addr = is_2addr;
	next_has_immval = has_immval;

	next_irq_handling = irq_handling;

	next_mult_start = mult_start;
	next_div_start = div_start;
	next_calc_a = calc_a;
	next_calc_b = calc_b;

	unique case(cycle)
		FETCH: begin
			// handle interrupt requests
			if(irq_needs_handling == 1'b1 && irq_handling == 1'b0) begin
				next_irq_handling = 1'b1;
				next_cycle = IRQ_SAVE_REGS;
			end else begin

			// get instructions
			unique case(subcycle)
				0: begin  // request new instruction at pc
					next_mem_addr = pc;
					`ASSIGN_NEXT_PC(pc + 1'b1);
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
					next_mem_addr = pc;
					`ASSIGN_NEXT_PC(pc + 1'b1);
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
						next_cycle = cycle_after_write;
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
				unique case(instr[WORD_BITS - 2 - SKIP_OP_BITS : WORD_BITS/2])
					4'b0000: begin  // register transfer
						next_regs[regidx2] = reg1;
						next_cycle = FETCH;
					end

					4'b0001: begin  // reg1 += reg2
						next_regs[regidx1] = reg1 + reg2;
						next_cycle = FETCH;
					end

					4'b0010: begin  // reg1 -= reg2
						next_regs[regidx1] = reg1 - reg2;
						next_cycle = FETCH;
					end

					4'b0011: begin  // reg1 <<= reg2
						next_regs[regidx1] = reg1 << reg2;
						next_cycle = FETCH;
					end

					4'b0100: begin  // reg1 >>= reg2
						next_regs[regidx1] = reg1 >> reg2;
						next_cycle = FETCH;
					end

					4'b0101: begin  // compare(reg1, reg2)
						next_regs[status_idx] = {
							2'b0,
							reg1 <= reg2,  // 5
							reg1 <  reg2,  // 4
							reg1 >= reg2,  // 3
							reg1 >  reg2,  // 2
							reg1 != reg2,  // 1
							reg1 == reg2   // 0
						};
						next_cycle = FETCH;
					end

					4'b0110: begin  // reg1 &= reg2
						next_regs[regidx1] = reg1 & reg2;
						next_cycle = FETCH;
					end

					4'b0111: begin  // reg1 |= reg2
						next_regs[regidx1] = reg1 | reg2;
						next_cycle = FETCH;
					end

`ifndef CPU_NO_MULT_DIV
					4'b1000: begin  // reg1 *= reg2
						unique case(subcycle)
							0: begin
								next_calc_a = reg1;
								next_calc_b = reg2;
								next_mult_start = 1'b1;
								next_subcycle = 1'b1;
							end
							1: begin  // fetch memory word
								next_mult_start = 1'b0;
								if(mult_finished) begin
									next_regs[regidx1] = mult_prod;
									next_cycle = FETCH;
									next_subcycle = 1'b0;
								end
							end
						endcase
					end

					4'b1001: begin  // reg1 /= reg2
						unique case(subcycle)
							0: begin
								next_calc_a = reg1;
								next_calc_b = reg2;
								next_div_start = 1'b1;
								next_subcycle = 1'b1;
							end
							1: begin  // fetch memory word
								next_div_start = 1'b0;
								if(div_finished) begin
									next_regs[regidx1] = div_quot;
									next_cycle = FETCH;
									next_subcycle = 1'b0;
								end
							end
						endcase
					end

					4'b1010: begin  // reg1 %= reg2
						unique case(subcycle)
							0: begin
								next_calc_a = reg1;
								next_calc_b = reg2;
								next_div_start = 1'b1;
								next_subcycle = 1'b1;
							end
							1: begin  // fetch memory word
								next_div_start = 1'b0;
								if(div_finished) begin
									next_regs[regidx1] = div_rem;
									next_cycle = FETCH;
									next_subcycle = 1'b0;
								end
							end
						endcase
					end
`endif

					// TODO
					/*4'b1011: begin  // reg1 = rol(reg1, reg2)
						next_regs[regidx1] = {
							reg1[WORD_BITS - 1 - reg2 : 0],
							reg1[WORD_BITS - 1 -: reg2]
						};
						next_cycle = FETCH;
					end

					4'b1100: begin  // reg1 = ror(reg1, reg2)
						next_regs[regidx1] = {
							reg1[0 +: reg2],
							reg1[WORD_BITS - 1 : reg2]
						};
						next_cycle = FETCH;
					end*/

					default: begin  // unknown instruction
						next_cycle = HALT;
					end
				endcase
			end
			// -------------------------------------------------------------------------

			// -------------------------------------------------------------------------
			// 1-register instructions with immediate value
			// -------------------------------------------------------------------------
			else if(is_1addr && has_immval) begin
				unique case(instr[WORD_BITS - 4 - SKIP_OP_BITS : REG_BITS])
					3'b000: begin  // transfer immediate value to register
						next_regs[regidx1] = immval;
						next_cycle = FETCH;
					end

					3'b001: begin  // transfer memory to register
						unique case(subcycle)
							0: begin   // request memory word pointed to by immval
								next_mem_addr = immval;
								next_mem_ready = 1'b1;
								next_subcycle = 1;
              end
							1: begin   // fetch memory word
								if(in_mem_ready) begin
									next_regs[regidx1] = in_mem_data;
									next_cycle = FETCH;
									next_subcycle = 0;
								end
							end
						endcase
					end

					3'b010: begin  // transfer register to memory
						next_mem_addr = immval;
						next_mem_data = reg1;
						next_cycle = WRITE_MEM;
						next_cycle_after_write = FETCH;
					end

					default: begin  // unknown instruction
						next_cycle = HALT;
					end
				endcase
			end  // is_1addr && has_immval
			// -------------------------------------------------------------------------

			// -------------------------------------------------------------------------
			// 1-register instructions without immediate value
			// -------------------------------------------------------------------------
			else if(is_1addr && !has_immval) begin
				unique case(instr[WORD_BITS - 4 - SKIP_OP_BITS : REG_BITS])
					4'b000: begin  // conditional jump to absolute address in register
						if(regs[status_idx][0] == 1'b1)
							`ASSIGN_NEXT_PC(reg1);
						next_cycle = FETCH;
					end

					4'b001: begin  // jump to absolute address in register
						`ASSIGN_NEXT_PC(reg1);
						next_cycle = FETCH;
					end

					4'b010: begin  // jump to relative address in register
						`ASSIGN_NEXT_PC(pc + reg1);
						next_cycle = FETCH;
					end

					4'b011: begin  // call absolute address in register
						unique case(subcycle2)  // 'subcycle' already used in WRITE_MEM
							0: begin  // push return address
								`ASSIGN_NEXT_PC(reg1);

								next_regs[sp_idx] = regs[sp_idx] - 1'b1;
								next_mem_addr = regs[sp_idx] - 1'b1;
								next_mem_data = pc;
								next_cycle = WRITE_MEM;
								next_cycle_after_write = EXEC;
								next_subcycle2 = 1;
						end
							1: begin  // push base pointer
								next_regs[sp_idx] = regs[sp_idx] - 1'b1;  // decrement sp
								next_regs[bp_idx] = regs[sp_idx] - 1'b1;  // bp = sp
								next_mem_addr = regs[sp_idx] - 1'b1;
								next_mem_data = regs[bp_idx];
								next_cycle = WRITE_MEM;
								next_cycle_after_write = FETCH;
								next_subcycle2 = 0;
							end
						default: begin
								next_subcycle2 = 0;
						end
						endcase
					end

					4'b100: begin  // bit-wise not of register
						next_regs[regidx1] = ~reg1;
						next_cycle = FETCH;
					end

					4'b101: begin  // logical not of register
						next_regs[regidx1] = !reg1;
						next_cycle = FETCH;
					end

					4'b110: begin  // push register
						next_regs[sp_idx] = regs[sp_idx] - 1'b1;
						next_mem_addr = regs[sp_idx] - 1'b1;
						next_mem_data = reg1;
						next_cycle = WRITE_MEM;
						next_cycle_after_write = FETCH;
					end

					4'b111: begin  // pop register
						// transfer memory to register
						unique case(subcycle)
							0: begin  // request memory word pointed to by sp
								next_regs[sp_idx] = regs[sp_idx] + 1'b1;
								next_mem_addr = regs[sp_idx];
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

					4'b1000: begin  // reg1 <<= 1
						next_regs[regidx1] = reg1 << 1;
						next_cycle = FETCH;
					end

					4'b1001: begin  // reg1 >>= 1
						next_regs[regidx1] = reg1 >> 1;
						next_cycle = FETCH;
					end

					4'b1010: begin  // reg1 = rol(reg1, 1)
						next_regs[regidx1] = {
							reg1[WORD_BITS - 2 : 0],
							reg1[WORD_BITS - 1]
						};
						next_cycle = FETCH;
					end

					4'b1011: begin  // reg1 = ror(reg1, 1)
						next_regs[regidx1] = {
							reg1[0],
							reg1[WORD_BITS - 1 : 1]
						};
						next_cycle = FETCH;
					end

					default: begin  // unknown instruction
						next_cycle = HALT;
					end
				endcase
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
				unique case(instr[WORD_BITS - 3 - SKIP_OP_BITS : 0])
					5'b00000: begin  // halt
						next_cycle = HALT;
					end

					5'b00001: begin  // nop
						next_cycle = FETCH;
					end

					5'b00010: begin  // return
						unique case(subcycle2)
							0: begin  // request base pointer pointed to by former sp (i.e. bp)
								next_regs[sp_idx] = regs[bp_idx] + 1'b1;  // sp = bp, increment sp
								next_mem_addr = regs[bp_idx];
								next_mem_ready = 1'b1;
								next_subcycle2 = 1;
							end
							1: begin  // request return address pointed to by sp
								if(in_mem_ready) begin
									next_regs[bp_idx] = in_mem_data;  // restore base pointer

									next_regs[sp_idx] = regs[sp_idx] + 1'b1;  // increment sp
									next_mem_addr = regs[sp_idx];
									next_mem_ready = 1'b1;
									next_subcycle2 = 2;
								end
							end
							2: begin  // fetch return address and jump to it
								if(in_mem_ready) begin
									`ASSIGN_NEXT_PC(in_mem_data);  // restore program counter

									next_cycle = FETCH;
									next_subcycle2 = 0;
								end
							end
							default: begin
								next_subcycle2 = 0;
							end
						endcase
					end

					5'b00011: begin  // return from isr
						// TODO: restore reg[status_idx]

						unique case(subcycle2)
							0: begin  // request base pointer pointed to by sp
								next_regs[sp_idx] = regs[bp_idx] + 1'b1;  // sp = bp, increment sp
								next_mem_addr = regs[bp_idx];
								next_mem_ready = 1'b1;
								next_subcycle2 = 1;
							end
							1: begin  // request return address pointed to by sp
								if(in_mem_ready) begin
									next_regs[bp_idx] = in_mem_data;  // restore base pointer

									next_regs[sp_idx] = regs[sp_idx] + 1'b1;  // increment sp
									next_mem_addr = regs[sp_idx];
									next_mem_ready = 1'b1;
									next_subcycle2 = 2;
								end
							end
							2: begin  // fetch return address and jump to it
								if(in_mem_ready) begin
									`ASSIGN_NEXT_PC(in_mem_data);  // restore program counter

									next_cycle = FETCH;
									next_subcycle2 = 0;
									next_irq_handling = 1'b0;
								end
							end
							default: begin
								next_subcycle2 = 0;
							end
						endcase
					end

					5'b00100: begin  // equal?
						next_regs[status_idx][0] = regs[status_idx][0];
						next_cycle = FETCH;
					end

					5'b00101: begin  // not equal?
						next_regs[status_idx][0] = regs[status_idx][1];
						next_cycle = FETCH;
					end

					5'b00110: begin  // greater?
						next_regs[status_idx][0] = regs[status_idx][2];
						next_cycle = FETCH;
					end

					5'b00111: begin  // greater or equal?
						next_regs[status_idx][0] = regs[status_idx][3];
						next_cycle = FETCH;
					end

					5'b01000: begin  // less?
						next_regs[status_idx][0] = regs[status_idx][4];
						next_cycle = FETCH;
					end

					5'b01001: begin  // less or equal?
						next_regs[status_idx][0] = regs[status_idx][5];
						next_cycle = FETCH;
					end

					5'b10000: begin  // active irq -> status reg
						next_regs[status_idx] = irq;
						next_cycle = FETCH;
					end

					default: begin  // unknown instruction
						next_cycle = HALT;
					end
				endcase
			end  // !is_1addr && !is_2addr && !has_immval
			// -------------------------------------------------------------------------

		end  // EXEC
		
		HALT: begin
		end

		IRQ_SAVE_REGS: begin
			unique case(subcycle2)  // 'subcycle' already used in WRITE_MEM
				0: begin  // push return address
					next_regs[sp_idx] = regs[sp_idx] - 1'b1;
					next_mem_addr = regs[sp_idx] - 1'b1;
					next_mem_data = pc;
					next_cycle = WRITE_MEM;
					next_cycle_after_write = IRQ_SAVE_REGS;
					next_subcycle2 = 1;
				end
				1: begin  // push base pointer
					next_regs[sp_idx] = regs[sp_idx] - 1'b1;
					next_mem_addr = regs[sp_idx] - 1'b1;
					next_mem_data = regs[bp_idx];
					next_cycle = WRITE_MEM;
					next_cycle_after_write = IRQ_EXEC;
					next_subcycle2 = 0;
				end
				default: begin
					next_subcycle2 = 0;
				end
			endcase
		end

		// TODO: save reg[status_idx] and put interrupt number in it

		IRQ_EXEC: begin
			// jump to interrupt service routine
			`ASSIGN_NEXT_PC(ISR_ADDR);
			next_cycle = FETCH;
		end

		default: begin
		end
	endcase
end
// ----------------------------------------------------------------------------


endmodule
