/**
 * flash memory with serial interface
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 10-aug-2024
 * @license see 'LICENSE' file
 *
 * references:
 *   - [flash] https://www.puyasemi.com/en/u_series511.html
 */


module flash_serial
#(
	parameter WORD_BITS      = 8,
	parameter ADDRESS_WORDS  = 2,

	parameter MAIN_CLK       = 50_000_000,
	parameter SERIAL_CLK     = 10_000_000
 )
(
	// main clock and reset
	input wire in_clk, in_rst,

	// memory access
	input wire in_enable, in_write, in_erase,
	// (start) address to read from or to write to
	input wire [WORD_BITS * ADDRESS_WORDS - 1 : 0] in_addr,
	// input data
	input wire [WORD_BITS - 1 : 0] in_data,
	// output data
	output wire [WORD_BITS - 1 : 0] out_data,
	// index of currently read word
	output wire [ADDRESS_WORDS*WORD_BITS - 1 : 0] out_word_ctr,
	// indicates that a word has been read
	output wire out_word_finished,
	// indicates that a new word is requested to write (one cycle before out_word_finished)
	output wire out_next_word,

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
localparam [WORD_BITS - 1 : 0] CMD_READ_STATUS   = WORD_BITS'(8'h05);
localparam [WORD_BITS - 1 : 0] CMD_WRITE         = WORD_BITS'(8'h02);
localparam [WORD_BITS - 1 : 0] CMD_READ          = WORD_BITS'(8'h03);
localparam [WORD_BITS - 1 : 0] CMD_WRITE_DISABLE = WORD_BITS'(8'h04);
localparam [WORD_BITS - 1 : 0] CMD_WRITE_ENABLE  = WORD_BITS'(8'h06);
localparam [WORD_BITS - 1 : 0] CMD_ERASE         = WORD_BITS'(8'h81);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// wait timer register, see [flash], p. 13, pp. 76-77
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam WAIT_INIT        = 1;
	localparam WAIT_RESET       = 1;
	localparam WAIT_AFTER_RESET = 1;
`else
	localparam WAIT_INIT        = MAIN_CLK/1000/1000 * 400; // 400 us
	localparam WAIT_RESET       = MAIN_CLK/1000/1000 * 2;   // 2 us
	localparam WAIT_AFTER_RESET = MAIN_CLK/1000/1000 * 50;  // 50 us
`endif

logic [$clog2(WAIT_INIT /*largest value*/) : 0]
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
logic serial_enable_tx, serial_enable_rx;
logic serial_clk, serial_clk_raw;
logic serial_data_out;

logic [WORD_BITS - 1 : 0] data_tx, data_rx;
logic [WORD_BITS - 1 : 0] word_rx, next_word_rx;

logic word_finished_tx, last_word_finished_tx = 1'b0;
logic word_finished_rx, last_word_finished_rx = 1'b0;
//wire bus_cycle_tx = word_finished_tx && ~last_word_finished_tx;
wire bus_cycle_rx = word_finished_rx && ~last_word_finished_rx;

logic word_requested_rx, last_word_requested_rx = 1'b0;
logic word_requested_tx, last_word_requested_tx = 1'b0;
//wire bus_cycle_req_rx = word_requested_rx && ~last_word_requested_rx;
wire bus_cycle_req_tx = word_requested_tx && ~last_word_requested_tx;

// read from flash on rising edge, write to flash on falling edge
serial_duplex #(
	.BITS(WORD_BITS), .LOWBIT_FIRST(1'b0),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
	.SERIAL_CLK_INACTIVE(1'b1), .SERIAL_DATA_INACTIVE(1'b0),
	.KEEP_SERIAL_CLK_RUNNING(1'b1),
	.TO_FPGA_FALLING_EDGE(1'b0) /* rx */,
	.FROM_FPGA_FALLING_EDGE(1'b1) /* tx */
)
serial_mod(
	.in_clk(in_clk), .in_rst(in_rst),
	.in_enable_fromfpga(serial_enable_tx),
	.in_enable_tofpga(serial_enable_rx),
	.in_serial(in_flash_data), .in_parallel(data_tx),
	.out_serial(serial_data_out), .out_parallel(data_rx),
	.out_clk(serial_clk), .out_clk_raw(serial_clk_raw),
	.out_word_finished_fromfpga(word_finished_tx),
	.out_next_word_fromfpga(word_requested_tx),
	.out_word_finished_tofpga(word_finished_rx),
	.out_next_word_tofpga(word_requested_rx)
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// outputs
// --------------------------------------------------------------------
logic flash_rst, flash_write_protect;
logic word_rdy, next_word_rdy;

assign out_flash_clk = serial_clk;
assign out_flash_rst = ~flash_rst;          // active low
assign out_flash_select = ~(serial_enable_tx | serial_enable_rx); // active low
assign out_flash_wp = ~flash_write_protect; // active low
assign out_flash_data = serial_data_out;

assign out_data = word_rx;
assign out_word_ctr = word_ctr;
assign out_word_finished = word_rdy;
assign out_next_word = next_word_rdy;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// states
// --------------------------------------------------------------------
typedef enum {
	Init, Reset, AfterReset,
	AwaitCommand,
	WriteCommandOnly,
	WriteCommandWithAddress, WriteAddress,
	WriteCommandWriteOneWord, WriteWord,
	WriteCommandReadOneWord, ReadWord,
	ReadData, WriteData, ErasedData
} t_state;

t_state state = Init, next_state = Init;
t_state data_state = ReadData, next_data_state = ReadData;

logic [WORD_BITS - 1 : 0] cmd = CMD_NOP, next_cmd = CMD_NOP;
logic [WORD_BITS - 1 : 0] data = 1'b0, next_data = 1'b0;
logic [1 : 0] cmd_phase = 1'b0, next_cmd_phase = 1'b0;

logic is_write_protected = 1'b1, next_is_write_protected = 1'b1;


always_ff@(posedge serial_clk_raw, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		state <= /*Reset*/ Init;
		data_state <= ReadData;

		cmd_phase <= 1'b0;

		word_ctr <= 1'b0;
		word_rdy <= 1'b0;

		wait_ctr <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;
		data_state <= next_data_state;

		cmd_phase <= next_cmd_phase;

		word_ctr <= next_word_ctr;
		word_rdy <= next_word_rdy;

		// timer register
		if(wait_ctr == wait_ctr_max)
			wait_ctr <= $size(wait_ctr)'(1'b0);
		else
			wait_ctr <= $size(wait_ctr)'(wait_ctr + 1'b1);
	end
end


always_ff@(posedge serial_clk_raw, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		word_rx <= 1'b0;

		last_word_finished_rx <= 1'b0;
		last_word_requested_rx <= 1'b0;
	end

	// clock
	else begin
		word_rx <= next_word_rx;

		last_word_finished_rx <= word_finished_rx;
		last_word_requested_rx <= word_requested_rx;
	end
end


always_ff@(negedge serial_clk_raw, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		is_write_protected <= 1'b1;
		data <= 1'b0;
		cmd <= CMD_NOP;

		last_word_finished_tx <= 1'b0;
		last_word_requested_tx <= 1'b0;
	end

	// clock
	else begin
		is_write_protected <= next_is_write_protected;
		data <= next_data;
		cmd <= next_cmd;

		last_word_finished_tx <= word_finished_tx;
		last_word_requested_tx <= word_requested_tx;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_data_state = data_state;
	next_is_write_protected = is_write_protected;

	next_data = data;
	next_cmd = cmd;
	next_cmd_phase = cmd_phase;

	next_word_ctr = word_ctr;
	next_word_rx = word_rx;
	next_word_rdy = 1'b0;

	wait_ctr_max = WAIT_RESET;
	serial_enable_tx = 1'b0;
	serial_enable_rx = 1'b0;
	data_tx = 1'b0;

	flash_rst = 1'b0;
	flash_write_protect = 1'b1;

	case(state)
		// ----------------------------------------------------
		// Init
		Init: begin
			wait_ctr_max = WAIT_INIT;
			if(wait_ctr == wait_ctr_max)
				next_state = Reset;
		end

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

				// read operation: [flash], p. 35
				if(in_write == 1'b0) begin
					next_state = WriteCommandWithAddress;
					next_data_state = ReadData;
					next_cmd = CMD_READ;
				end

				// remove write protection on first write attempt
				else if(is_write_protected == 1'b1) begin
					if(cmd_phase == 2'd0) begin
						// write enable: [flash], p. 26
						next_state = WriteCommandOnly;
						next_data_state = AwaitCommand;
						next_cmd = CMD_WRITE_ENABLE;
						next_cmd_phase = 2'd1;
					end else if(cmd_phase == 2'd1) begin
						// read status register: [flash], pp. 28-29
						next_state = WriteCommandReadOneWord;
						next_data_state = AwaitCommand;
						next_cmd = CMD_READ_STATUS;
						next_cmd_phase = 2'd2;
					end else begin
						// unlock: [flash], pp. 33-34
						next_state = WriteCommandWriteOneWord;
						next_data_state = AwaitCommand;
						next_cmd = CMD_WRITE_STATUS;
						//next_data = { word_rx[7], 5'b0, word_rx[1:0] };
						next_data = 8'b00000010;
						next_cmd_phase = 2'd0;
						next_is_write_protected = 1'b0;
					end
				end

				else if(in_erase == 1'b1) begin
					if(cmd_phase == 1'd0) begin
						// write enable: [flash], p. 26
						next_state = WriteCommandOnly;
						next_data_state = AwaitCommand;
						next_cmd = CMD_WRITE_ENABLE;
						next_cmd_phase = 1'd1;
					end else begin
						// write 1 bits: [flash], p. 51
						next_state = WriteCommandWithAddress;
						next_data_state = ErasedData;
						next_cmd = CMD_ERASE;
						next_cmd_phase = 1'd0;
					end
				end

				// write operation: [flash], pp. 56-57
				// (erase byte to 0xff before writing a new value)
				else if(in_write == 1'b1) begin
					if(cmd_phase == 1'd0) begin
						// write enable: [flash], p. 26
						next_state = WriteCommandOnly;
						next_data_state = AwaitCommand;
						next_cmd = CMD_WRITE_ENABLE;
						next_cmd_phase = 1'd1;
					end else begin
						// write 0 bits: [flash], pp. 56-57
						next_state = WriteCommandWithAddress;
						next_data_state = WriteData;
						next_cmd = CMD_WRITE;
						next_cmd_phase = 1'd0;
					end
				end
			end
		end
		// ----------------------------------------------------

		// ----------------------------------------------------
		// write command word with no address
		WriteCommandOnly: begin
			serial_enable_tx = 1'b1;
			data_tx = cmd;

			if(bus_cycle_req_tx == 1'b1)
				next_state = data_state;
		end

		// write command word and one data word
		WriteCommandWriteOneWord: begin
			serial_enable_tx = 1'b1;
			flash_write_protect = 1'b0;
			data_tx = cmd;

			if(bus_cycle_req_tx == 1'b1)
				next_state = WriteWord;
		end

		// write one data word
		WriteWord: begin
			serial_enable_tx = 1'b1;
			flash_write_protect = 1'b0;
			data_tx = data;

			if(bus_cycle_req_tx == 1'b1)
				next_state = data_state;
		end

		// write command word and read one data word
		WriteCommandReadOneWord: begin
			serial_enable_tx = 1'b1;
			data_tx = cmd;

			if(bus_cycle_req_tx == 1'b1)
				next_state = ReadWord;
		end

		// read one data word
		ReadWord: begin
			serial_enable_rx = 1'b1;

			if(bus_cycle_rx == 1'b1) begin
				next_word_rx = data_rx;
				next_state = data_state;
			end
		end

		// write command word followed by an address
		WriteCommandWithAddress: begin
			serial_enable_tx = 1'b1;
			data_tx = cmd;

			if(bus_cycle_req_tx == 1'b1) begin
				next_state = WriteAddress;
				next_word_ctr = 1'b0;
			end
		end

		// write address words
		WriteAddress: begin
			serial_enable_tx = 1'b1;
			data_tx = cur_addr_word;

			// advance word counter one flash clock cycle before transmission ends
			if(bus_cycle_req_tx == 1'b1) begin
				if(word_ctr != ADDRESS_WORDS - 1'b1) begin
					next_word_ctr = $size(word_ctr)'(word_ctr + 1'b1);
				end else begin
					next_word_ctr = 1'b0;
					next_state = data_state;
				end
			end
		end
		// ----------------------------------------------------

		// ----------------------------------------------------
		// read data words
		ReadData: begin
			serial_enable_rx = 1'b1;

			if(bus_cycle_rx == 1'b1) begin
				next_word_rx = data_rx;
				next_word_ctr = $size(word_ctr)'(word_ctr + 1'b1);
				next_word_rdy = 1'b1;
			end

			if(in_enable == 1'b0)
				next_state = AwaitCommand;
		end

		// write data words
		WriteData: begin
			serial_enable_tx = 1'b1;
			flash_write_protect = 1'b0;
			data_tx = in_data;

			// advance word counter one flash clock cycle before transmission ends
			if(bus_cycle_req_tx == 1'b1) begin
				next_word_ctr = $size(word_ctr)'(word_ctr + 1'b1);
				next_word_rdy = 1'b1;
			end

			if(in_enable == 1'b0)
				next_state = AwaitCommand;
		end

		// erased data
		ErasedData: begin
			next_word_rdy = 1'b1;

			if(in_enable == 1'b0)
				next_state = AwaitCommand;
		end
		// ----------------------------------------------------
	endcase

`ifdef __IN_SIMULATION__
	$display("*** flash_serial: %s, rst=%b, ",
		state.name(), flash_rst,
		"tx=%x, rx=%x, addr=%x, word=%d. ***",
		data_tx, data_rx, cur_addr_word, word_ctr);
`endif
end
// --------------------------------------------------------------------

endmodule
