/**
 * runs a c++ program in rom on a rv cpu
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date 31-aug-2025, 13-sep-2025
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://github.com/YosysHQ/picorv32/tree/main/picosoc
 *   - https://github.com/grughuhler/picorv32_tang_nano_unified/tree/main
 */


module rv_main
#(
	parameter MAIN_CLK = 27_000_000,
	parameter SLOW_CLK =        500
)
(
	// main clock
	input clk27,

	// keys
	input  [1 : 0] key,

	// segment display
	//output [6:0] seg,
	//output seg_sel,

	// leds
	output [5 : 0] led,
	output [7 : 0] ledg
);


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
//localparam MAIN_CLK = 27_000_000;
//localparam SLOW_CLK =      0_500;

logic clock;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(1'b0), .out_clk(clock));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
logic rst, btn;

// active-low button
debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

// active-low button
debounce_button debounce_key1(.in_clk(clock), .in_rst(1'b0),
	.in_signal(~key[1]), .out_debounced(btn));
// ----------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// overall state
// ---------------------------------------------------------------------------
typedef enum bit [1 : 0]
{
	RESET_ALL, COPY_ROM, RUN_CPU
} t_state;

t_state state = RESET_ALL, next_state = RESET_ALL;

always_ff@(posedge clock) begin
	if(rst == 1'b1)
		state <= RESET_ALL;
	else
		state <= next_state;
end

always_comb begin
	next_state = state;

	case(state)
		RESET_ALL: begin
			next_state = COPY_ROM;
		end

		COPY_ROM: begin
			if(memcpy_finished == 1'b1)
				next_state = RUN_CPU;
		end

		RUN_CPU: begin
		end
	endcase
end

wire reset = (state == RESET_ALL);
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// instantiate ram
// ---------------------------------------------------------------------------
localparam ADDR_BITS = 12;
localparam DATA_BITS = 32;

// ram port 1
wire write_enable_1;
logic [ADDR_BITS - 1 : 0] addr_1;
logic [DATA_BITS - 1 : 0] in_data_1, out_data_1;

// ram port 2
logic [ADDR_BITS - 1 : 0] addr_2;
logic [DATA_BITS - 1 : 0] out_data_2;

// multiport not supported by hardware: use define: RAM_DISABLE_PORT2
ram_2port #(
	.ADDR_BITS(ADDR_BITS), .WORD_BITS(DATA_BITS),
	.ALL_WRITE(1'b0)
)
ram_mod(.in_rst(reset),

	// port 1 (reading and writing)
	.in_clk_1(clock),
	.in_read_ena_1(1'b1), .in_write_ena_1(write_enable_1),
	.in_addr_1(addr_1), .in_data_1(in_data_1), .out_data_1(out_data_1)

`ifndef RAM_DISABLE_PORT2
	,
	// port 2 (reading)
	.in_clk_2(clock),
	.in_read_ena_2(1'b1), .in_write_ena_2(1'b0),
	.in_addr_2(addr_2), .in_data_2(DATA_BITS'('b0)), .out_data_2(out_data_2)
`endif
);
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// instantiate rom
// ---------------------------------------------------------------------------
localparam ROM_ADDR_BITS = 8; //rom.ADDR_BITS;  // use value from generated rom.sv

logic [DATA_BITS - 1 : 0] out_rom_data;
rom rom_mod(
	.in_addr(addr_1[ROM_ADDR_BITS - 1 : 0]),
	.out_data(out_rom_data)
);
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// copy rom to ram
// ---------------------------------------------------------------------------
wire memcpy_finished;
logic [ROM_ADDR_BITS - 1 : 0] memcpy_addr;
logic [DATA_BITS - 1 : 0] memcpy_data;
logic memcpy_write_enable;

memcpy #(
	.ADDR_BITS(ROM_ADDR_BITS), .NUM_WORDS(2**ROM_ADDR_BITS),
	.WORD_BITS(DATA_BITS))
memcpy_mod(
	.in_clk(clock),
	.in_rst(reset),

	.in_word(out_rom_data),
	.out_word(memcpy_data),
	.out_addr(memcpy_addr),

	.out_read_enable(),
	.out_write_enable(memcpy_write_enable),
	.in_read_finished(1'b1),
	.in_write_finished(1'b1),

	.out_finished(memcpy_finished)
);
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// cpu
// ---------------------------------------------------------------------------
wire clock_cpu;

wire [DATA_BITS - 1 : 0] cpu_irq;
wire [DATA_BITS - 1 : 0] cpu_irq_ended;
wire cpu_trap;

logic cpu_mem_valid;
logic cpu_mem_ready = 1'b0;
wire [31 : 0] cpu_addr;
logic [3 : 0] cpu_bytesel;  // selects byte to write to, 0: read
logic cpu_write_enable;

logic [DATA_BITS - 1 : 0] cpu_data;
logic [DATA_BITS - 1 : 0] write_data, next_write_data;

// instantiate cpu
picorv32 #(
	.COMPRESSED_ISA(1'b0), .REGS_INIT_ZERO(1'b0),
	.ENABLE_MUL(1'b1), .ENABLE_DIV(1'b1), .BARREL_SHIFTER(1'b1),
	.PROGADDR_RESET(32'h0),                            // initial program counter
	.ENABLE_IRQ(1'b1), .PROGADDR_IRQ(32'h0040),        // see symbol table for _isr_entrypoint
	.ENABLE_IRQ_QREGS(1'b0), .ENABLE_IRQ_TIMER(1'b0),  // non-standard
	.STACKADDR({ (ADDR_BITS /*- 2*/){ 1'b1 } } - 4'hf) // initial stack pointer
)
cpu_mod(
	.resetn(~reset),
	.clk(clock_cpu),

	// interrupts
	.irq(cpu_irq),             // in
	.eoi(cpu_irq_ended),       // out,
	.trap(cpu_trap),           // out,

	// memory interface
	.mem_ready(cpu_mem_ready), // in
	.mem_valid(cpu_mem_valid), // out
	.mem_addr(cpu_addr),       // out
	.mem_wstrb(cpu_bytesel),   // out
	.mem_wdata(cpu_data),      // out
	.mem_rdata(out_data_1),    // in

	.pcpi_rd(32'b0),
	.pcpi_wr(1'b0),
	.pcpi_wait(1'b0),
	.pcpi_ready(1'b0)
);


// switch between cpu and memcpy
assign clock_cpu = ((state == RUN_CPU || state == RESET_ALL) ? clock : 1'b0);
assign addr_1 = (state == RUN_CPU ? cpu_addr[ADDR_BITS + 2 - 1 : 2] : memcpy_addr);
assign in_data_1 = (state == RUN_CPU ? write_data : memcpy_data);
assign write_enable_1 = (state == RUN_CPU ? cpu_write_enable : memcpy_write_enable);

// interrupts
assign cpu_irq = { 28'b0, btn, 3'b0 };
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// manage memory read and write access by cpu
// ---------------------------------------------------------------------------
logic [DATA_BITS - 1 : 0] write_data_sel;

// address to watch
logic [ADDR_BITS - 1 : 0] addr_watch;
logic [DATA_BITS - 1 : 0] data_watch, next_data_watch;

memsel #(
	.WORD_BITS(DATA_BITS), .BYTE_BITS(8))
memsel_mod(
	.in_word_1(cpu_data),
	.in_word_2(out_data_1),
	.in_sel(cpu_bytesel),
	.out_word(write_data_sel)
);


localparam READ_CYCLES = 1;
localparam WRITE_CYCLES = 1;
logic [1 : 0] read_cycle = 1'b0, write_cycle = 1'b0;

typedef enum bit [3 : 0]
{
	CPU_WAIT_MEM, CPU_MEM_READY,
	CPU_PREPARE_WRITE, CPU_WRITE
} t_state_memaccess;

t_state_memaccess state_memaccess = CPU_WAIT_MEM, next_state_memaccess = CPU_WAIT_MEM;

always_ff@(posedge clock) begin
	state_memaccess <= next_state_memaccess;
	write_data <= next_write_data;
	data_watch <= next_data_watch;

	if(read_cycle == READ_CYCLES || state_memaccess != CPU_MEM_READY)
		read_cycle <= 1'b0;
	else
		read_cycle <= read_cycle + 1'b1;

	if(write_cycle == WRITE_CYCLES || state_memaccess != CPU_WRITE)
		write_cycle <= 1'b0;
	else
		write_cycle <= write_cycle + 1'b1;
end

always_comb begin
	next_state_memaccess = state_memaccess;
	next_write_data = write_data;
	cpu_mem_ready = 1'b0;
	cpu_write_enable = 1'b0;
	next_data_watch = data_watch;

	case(state_memaccess)
		CPU_WAIT_MEM: begin
			if(cpu_mem_valid == 1'b1) begin
				if(cpu_bytesel == 1'b0)
					next_state_memaccess = CPU_MEM_READY;
				else
					next_state_memaccess = CPU_PREPARE_WRITE;
			end
		end

		CPU_MEM_READY: begin
			// skip cycles to fetch the cpu's requested data from the memory
			if(read_cycle == READ_CYCLES) begin
				cpu_mem_ready = 1'b1;
				next_state_memaccess = CPU_WAIT_MEM;
			end
		end

		CPU_PREPARE_WRITE: begin
			next_write_data = write_data_sel;
			next_state_memaccess = CPU_WRITE;
			if(addr_1 == addr_watch)
				next_data_watch = write_data_sel;
		end

		CPU_WRITE: begin
			cpu_write_enable = 1'b1;
			// may need to stay in this state for two cycles
			if(write_cycle == WRITE_CYCLES)
				next_state_memaccess = CPU_MEM_READY;
		end

		endcase
end
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// leds for debugging
// ---------------------------------------------------------------------------
assign led[0] = ~(state == COPY_ROM);
assign led[1] = ~(state == RUN_CPU);
assign led[2] = ~(state_memaccess == CPU_WAIT_MEM);
assign led[3] = ~(state_memaccess == CPU_MEM_READY);
assign led[4] = ~(state_memaccess == CPU_PREPARE_WRITE || state_memaccess == CPU_WRITE);
//assign led[5] = ~(state_memaccess == CPU_WRITE);
assign led[5] = ~data_watch[0];


// watch the 0x3f00 and 0x3f01 addresses for the memory test in main.cpp
assign addr_2 = (16'h3f00 >> 2'h2);
assign addr_watch = (16'h3f04 >> 2'h2);
assign ledg[7:0] = out_data_2[7 : 0];
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// segment display for watched variable
// ---------------------------------------------------------------------------
/*wire sevenseg_clk;
localparam SEVENSEG_CLK = 100;

clkgen #(
	.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SEVENSEG_CLK),
	.CLK_INIT(1'b1)
)
sevenseg_clk_mod
(
	.in_clk(clk27), .in_rst(reset),
	.out_clk(sevenseg_clk)
);

sevenseg_multi #(
	.NUM_LEDS(2), .ZERO_IS_ON(1'b1),
	.INVERSE_NUMBERING(1'b1), .ROTATED(1'b1)
)
sevenseg_mod(.in_clk(sevenseg_clk), .in_rst(reset),
	.in_digits(out_data_2[7:0]), .out_leds(seg), .out_sel(seg_sel));*/
// ---------------------------------------------------------------------------


endmodule
