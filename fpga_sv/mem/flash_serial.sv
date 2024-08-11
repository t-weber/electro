/**
 * flash memory with serial interface
 * @author Tobias Weber
 * @date 10-aug-2024
 * @license see 'LICENSE' file
 *
 * references:
 *   - [flash] https://www.puyasemi.com/en/u_series511.html
 */


module flash_serial
#(
	parameter WORD_BITS     = 8,
	parameter ADDRESS_WORDS = 2,

	parameter MAIN_CLK   = 50_000_000,
	parameter SERIAL_CLK = 10_000_000
 )
(
	// main clock and reset
	input wire in_clk, in_rst,

	// memory access
	input wire in_enable, in_read,
	// (start) address to read from or to write to
	input wire [WORD_BITS * ADDRESS_WORDS - 1 : 0] in_addr,
	// input data
	input wire [WORD_BITS - 1 : 0] in_data,
	// output data
	output wire [WORD_BITS - 1 : 0] out_data,
	// index of currently read word
	output wire [ADDRESS_WORDS*WORD_BITS - 1 : 0] out_word_ctr,
	// indicates that a word has been read or a new word is requested to write
	output wire out_word_ready,

	// serial interface to flash controller
	output wire out_flash_rst,     // reset
	output wire out_flash_clk,     // serial clock
	output wire out_flash_select,  // chip select
	output wire out_flash_wp,      // write protect
	output wire out_flash_data,    // serial data from fpga to flash
	input wire in_flash_data       // serial data from flash to fpga
);


// --------------------------------------------------------------------
// commands, see [flash], pp. 22-24
// --------------------------------------------------------------------
localparam [WORD_BITS - 1 : 0] CMD_NOP           = WORD_BITS'(8'h00);
localparam [WORD_BITS - 1 : 0] CMD_WRITE_STATUS  = WORD_BITS'(8'h01);
localparam [WORD_BITS - 1 : 0] CMD_WRITE         = WORD_BITS'(8'h02);
localparam [WORD_BITS - 1 : 0] CMD_READ          = WORD_BITS'(8'h03);
localparam [WORD_BITS - 1 : 0] CMD_WRITE_DISABLE = WORD_BITS'(8'h04);
localparam [WORD_BITS - 1 : 0] CMD_WRITE_ENABLE  = WORD_BITS'(8'h06);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// wait timer register, see [flash], pp. 76-77
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam WAIT_RESET       = 1;
	localparam WAIT_AFTER_RESET = 1;
`else
	localparam WAIT_RESET       = MAIN_CLK/1000/1000;      // 1 us
	localparam WAIT_AFTER_RESET = MAIN_CLK/1000/1000 * 29; // 29 us
`endif

logic [$clog2(WAIT_AFTER_RESET /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// word counter for addresses
// --------------------------------------------------------------------
logic [ADDRESS_WORDS*WORD_BITS - 1'b1 : 0] word_ctr = 0, next_word_ctr = 0;

wire [WORD_BITS - 1'b1 : 0] cur_addr_word;

genvar idx;
generate
for(idx = 0; idx < WORD_BITS; ++idx)
begin : addr_gen
	assign cur_addr_word[idx] =
		in_addr[(ADDRESS_WORDS - (word_ctr + 1'b1))*WORD_BITS + idx];
end
endgenerate
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// serial interface
// --------------------------------------------------------------------
logic serial_enable, serial_ready, serial_clk;
logic serial_data_out;

logic [WORD_BITS - 1 : 0] data_tx, data_rx;
logic [WORD_BITS - 1 : 0] word_rx, next_word_rx;

logic word_finished, last_word_finished = 1'b0;
wire bus_cycle = word_finished && ~last_word_finished;
//wire bus_cycle_next = ~word_finished && last_word_finished;

logic word_requested, last_word_requested = 1'b0;
wire bus_cycle_req = word_requested && ~last_word_requested;

serial #(
	.BITS(WORD_BITS), .LOWBIT_FIRST(1'b0),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
	.SERIAL_CLK_INACTIVE(1'b1), .SERIAL_DATA_INACTIVE(1'b0),
	.KEEP_SERIAL_CLK_RUNNING(1'b0)
)
serial_mod(
	.in_clk(in_clk), .in_rst(in_rst),
	.in_parallel(data_tx), .in_enable(serial_enable),
	.in_serial(in_flash_data), .out_serial(serial_data_out),
	.out_word_finished(word_finished), .out_next_word(word_requested),
	.out_ready(serial_ready), .out_clk(serial_clk),
	.out_parallel(data_rx)
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// outputs
// --------------------------------------------------------------------
logic flash_rst, flash_write_protect;
logic word_rdy, next_word_rdy;
logic word_fin, next_word_fin;

assign out_flash_clk = serial_clk;
assign out_flash_rst = ~flash_rst;          // active low
assign out_flash_select = ~serial_enable;   // active low
assign out_flash_wp = ~flash_write_protect; // active low
assign out_flash_data = serial_data_out;

assign out_data = word_rx;
assign out_word_ctr = word_ctr;
assign out_word_ready = word_rdy;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// states
// --------------------------------------------------------------------
typedef enum {
	Reset, AfterReset,
	AwaitCommand,
	WriteCommandOnly,
	WriteCommandOneByte, WriteByte,
	WriteCommand, WriteAddress,
	ReadData, WriteData
} t_state;

t_state state = Reset, next_state = Reset;
t_state data_state = ReadData, next_data_state = ReadData;

logic [WORD_BITS - 1 : 0] cmd = CMD_NOP, next_cmd = CMD_NOP;
logic [WORD_BITS - 1 : 0] data = 1'b0, next_data = 1'b0;
logic [1 : 0] cmd_phase = 1'b0, next_cmd_phase = 1'b0;


// state flip-flops
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		state <= Reset;
		data_state <= ReadData;

		data <= 1'b0;
		cmd <= CMD_NOP;
		cmd_phase <= 1'b0;

		word_rx <= 1'b0;
		word_ctr <= 1'b0;
		word_fin <= 1'b0;
		word_rdy <= 1'b0;

		wait_ctr <= 1'b0;

		last_word_finished <= 1'b0;
		last_word_requested <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;
		data_state <= next_data_state;

		data <= next_data;
		cmd <= next_cmd;
		cmd_phase <= next_cmd_phase;

		word_rx <= next_word_rx;
		word_ctr <= next_word_ctr;
		word_fin <= next_word_fin;
		word_rdy <= next_word_rdy;

		// timer register
		if(wait_ctr == wait_ctr_max) begin
			// reset timer counter
			wait_ctr <= $size(wait_ctr)'(1'b0);
		end else begin
			// next timer counter
			wait_ctr <= $size(wait_ctr)'(wait_ctr + 1'b1);
		end

		last_word_finished <= word_finished;
		last_word_requested <= word_requested;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_data_state = data_state;

	next_data = data;
	next_cmd = cmd;
	next_cmd_phase = cmd_phase;

	next_word_ctr = word_ctr;
	next_word_rx = word_rx;
	next_word_fin = word_fin;
	next_word_rdy = 1'b0;

	wait_ctr_max = WAIT_RESET;
	serial_enable = 1'b0;
	data_tx = 0;

	flash_rst = 1'b0;
	flash_write_protect = 1'b1;

	case(state)
		// ----------------------------------------------------
		// send reset
		Reset: begin
			flash_rst = 1'b1;
			next_cmd_phase = 1'b0;

			wait_ctr_max = WAIT_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = AfterReset;
		end

		// wait for device reset
		AfterReset: begin
			wait_ctr_max = WAIT_AFTER_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = AwaitCommand;
		end
		// ----------------------------------------------------

		// ----------------------------------------------------
		// idle
		AwaitCommand: begin
			if(in_enable == 1'b1) begin
				next_word_ctr = 1'b0;

				if(in_read == 1'b1) begin
					// read operation: [flash], p. 35
					next_state = WriteCommand;
					next_data_state = ReadData;
					next_cmd = CMD_READ;
				end else begin
					if(cmd_phase == 2'd0) begin
						// write enable: [flash], p. 26
						next_state = WriteCommandOnly;
						next_data_state = AwaitCommand;
						next_cmd = CMD_WRITE_ENABLE;
						next_cmd_phase = 2'd1;
					end else if(cmd_phase == 2'd1) begin
						// unlock: [flash], pp. 33-34
						next_state = WriteCommandOneByte;
						next_data_state = AwaitCommand;
						next_cmd = CMD_WRITE_STATUS;
						next_data = 8'b0000_0010;
						next_cmd_phase = 2'd2;
					end else if(cmd_phase == 2'd2) begin
						// write enable: [flash], p. 26
						next_state = WriteCommandOnly;
						next_data_state = AwaitCommand;
						next_cmd = CMD_WRITE_ENABLE;
						next_cmd_phase = 2'd3;
					end else begin
						// write operation: [flash], pp. 56-57
						next_state = WriteCommand;
						next_data_state = WriteData;
						next_cmd = CMD_WRITE;
						next_cmd_phase = 2'd0;
					end
				end
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write command word with no address
		WriteCommandOnly: begin
			serial_enable = 1'b1;
			data_tx = cmd;

			if(bus_cycle == 1'b1)
				next_state = data_state;
		end

		// write command word with one data byte
		WriteCommandOneByte: begin
			serial_enable = 1'b1;
			data_tx = cmd;

			if(bus_cycle == 1'b1)
				next_state = WriteByte;
		end

		// write one data byte
		WriteByte: begin
			serial_enable = 1'b1;
			data_tx = data;

			if(bus_cycle == 1'b1)
				next_state = data_state;
		end

		// write command word followed by an address
		WriteCommand: begin
			serial_enable = 1'b1;
			data_tx = cmd;

			if(bus_cycle_req == 1'b1) begin
				next_state = WriteAddress;
				next_word_ctr = 1'b0;
			end
		end

		// write address words
		WriteAddress: begin
			serial_enable = 1'b1;
			data_tx = cur_addr_word;

			// advance word counter one flash clock cycle before transmission ends
			if(bus_cycle_req == 1'b1) begin
				if(word_ctr != ADDRESS_WORDS - 1'b1) begin
					next_word_ctr = $size(word_ctr)'(word_ctr + 1'b1);
				end else begin
					next_state = data_state;
					next_word_fin = 1'b1;
					next_word_ctr = 1'b0;
				end
			end
		end
		// ----------------------------------------------------

		// ----------------------------------------------------
		// read data words
		ReadData: begin
			serial_enable = 1'b1;

			if(bus_cycle == 1'b1) begin
				next_word_rx = data_rx;
				next_word_ctr = $size(word_ctr)'(word_ctr + 1'b1);
				next_word_rdy = 1'b1;
			end

			if(in_enable == 1'b0)
				next_state = AwaitCommand;
		end
		// ----------------------------------------------------

		// ----------------------------------------------------
		// write data words
		WriteData: begin
			serial_enable = 1'b1;
			flash_write_protect = 1'b0;
			data_tx = in_data;

			// advance word counter one flash clock cycle before transmission ends
			if(bus_cycle_req == 1'b1) begin
				next_word_ctr = $size(word_ctr)'(word_ctr + 1'b1);
				next_word_rdy = 1'b1;
				next_word_fin = 1'b1;
			end

			// transmission ends -> next state
			if(bus_cycle == 1'b1 && next_word_fin == 1'b1)
				next_word_fin = 1'b0;

			if(in_enable == 1'b0)
				next_state = AwaitCommand;
		end
		// ----------------------------------------------------
	endcase

`ifdef __IN_SIMULATION__
	$display("*** flash_serial: %s, rst=%b, ena=%b, ",
		state.name(), flash_rst, serial_enable,
		"rdy=%b, tx=%x, rx=%x, addr=%x, word=%d, cycle=%b. ***",
		serial_ready, data_tx, data_rx, cur_addr_word, word_ctr, bus_cycle);
`endif
end
// --------------------------------------------------------------------

endmodule
