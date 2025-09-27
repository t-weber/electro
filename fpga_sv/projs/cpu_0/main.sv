/**
 * simple cpu test
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date september-2025
 * @license see 'LICENSE' file
 */

module cpuctrl
#(
	parameter MAIN_CLK = 27_000_000,
	parameter SYS_CLK  =         10
)
(
	// main clock
	input clk27,

	// keys
	input  [1 : 0] key,

	// leds
	output [2 : 0] led,
	output [9 : 0] ledr
);


// ----------------------------------------------------------------------------
// parameters
// ----------------------------------------------------------------------------
localparam ADDR_BITS = 3;
localparam DATA_BITS = 8;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// create system clock from input clock
// ----------------------------------------------------------------------------
logic clock;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SYS_CLK))
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
// ram port 1
wire write_enable_1;
logic [ADDR_BITS - 1 : 0] addr_1;
logic [DATA_BITS - 1 : 0] in_data_1, out_data_1;

`ifndef RAM_DISABLE_PORT2
	// ram port 2
	logic [ADDR_BITS - 1 : 0] addr_2;
	logic [DATA_BITS - 1 : 0] out_data_2;
`endif

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
localparam ROM_ADDR_BITS = 3; //rom.ADDR_BITS;  // use value from generated rom.sv

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
	.in_clk(clock), .in_rst(reset),

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

wire cpu_mem_valid;
logic cpu_mem_ready = 1'b0;
wire cpu_mem_write;
wire [ADDR_BITS - 1 : 0] cpu_addr;

wire [DATA_BITS - 1 : 0] cpu_data;
logic [DATA_BITS - 1 : 0] write_data, next_write_data;
wire [DATA_BITS - 1 : 0] cpu_instr;

// instantiate cpu
cpu #(.ADDR_BITS(ADDR_BITS), .WORD_BITS(DATA_BITS))
cpu_mod(
	.in_clk(clock_cpu), .in_rst(reset),

	// memory interface
	.in_mem_ready(cpu_mem_ready),
	.in_mem_data(out_data_1),
	.out_mem_ready(cpu_mem_valid),
	.out_mem_addr(cpu_addr),
	.out_mem_data(cpu_data),
	.out_mem_write(cpu_mem_write),

	.out_instr(cpu_instr)
);
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// switch between cpu and memcpy
// ---------------------------------------------------------------------------
logic cpu_write_enable;
assign clock_cpu = ((state == RUN_CPU || state == RESET_ALL) ? clock : 1'b0);
assign addr_1 = (state == RUN_CPU ? cpu_addr : memcpy_addr);
assign in_data_1 = (state == RUN_CPU ? write_data : memcpy_data);
assign write_enable_1 = (state == RUN_CPU ? cpu_write_enable : memcpy_write_enable);
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// manage memory read and write access by cpu
// ---------------------------------------------------------------------------
// addresses to watch
//logic [ADDR_BITS - 1 : 0] addr_watch;
//logic [DATA_BITS - 1 : 0] data_watch, next_data_watch;

localparam READ_CYCLES = 1;
localparam WRITE_CYCLES = 1;
logic [1 : 0] read_cycle = 1'b0, write_cycle = 1'b0;

typedef enum bit [3 : 0]
{
	CPU_WAIT_MEM, CPU_MEM_READY,
	CPU_PREPARE_WRITE, CPU_MEM_WRITE
} t_state_memaccess;

t_state_memaccess state_memaccess = CPU_WAIT_MEM, next_state_memaccess = CPU_WAIT_MEM;


always_ff@(posedge clock) begin
	if(reset == 1'b1) begin
		state_memaccess <= CPU_WAIT_MEM;
		write_data <= 1'b0;
		//data_watch <= 1'b0;
		read_cycle <= 1'b0;
		write_cycle <= 1'b0;
	end else begin
		state_memaccess <= next_state_memaccess;
		write_data <= next_write_data;
		//data_watch <= next_data_watch;

		if(read_cycle == READ_CYCLES || state_memaccess != CPU_MEM_READY)
			read_cycle <= 1'b0;
		else
			read_cycle <= read_cycle + 1'b1;

		if(write_cycle == WRITE_CYCLES || state_memaccess != CPU_MEM_WRITE)
			write_cycle <= 1'b0;
		else
			write_cycle <= write_cycle + 1'b1;
	end
end


always_comb begin
	next_state_memaccess = state_memaccess;
	next_write_data = write_data;
	cpu_mem_ready = 1'b0;
	cpu_write_enable = 1'b0;
	//next_data_watch = data_watch;

	case(state_memaccess)
		CPU_WAIT_MEM: begin
			if(cpu_mem_valid == 1'b1) begin
				if(cpu_mem_write == 1'b0)
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
			next_write_data = out_data_1;
			next_state_memaccess = CPU_MEM_WRITE;
			//if(addr_1 == addr_watch)  // program wrote to watched variable
			//	next_data_watch = out_data_1;
		end

		CPU_MEM_WRITE: begin
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
assign led[2] = ~(state_memaccess == CPU_MEM_WRITE);

assign ledr[DATA_BITS - 1 : 0] = cpu_instr;
assign ledr[9 : DATA_BITS] = 1'b0;
// ---------------------------------------------------------------------------


endmodule
