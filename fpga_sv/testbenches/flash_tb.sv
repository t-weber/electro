/**
 * serial flash memory testbench
 * @author Tobias Weber
 * @date 10-aug-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -D__IN_SIMULATION__ -o flash_tb flash_tb.sv ../mem/flash_serial.sv ../comm/serial_duplex.sv ../clock/clkgen.sv
 * ./flash_tb
 * gtkwave flash_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns
`default_nettype /*wire*/ none  // no implicit declarations


module flash_tb;
	localparam VERBOSE    = 0;
	localparam ITERS      = 1024;

	localparam BITS       = 8;
	localparam ADDR_WORDS = 2;

	localparam MAIN_CLK   = 1_000_000;
	localparam SERIAL_CLK = 250_000;


	typedef enum bit [2 : 0]
	{
		Reset,
		WriteData, WriteDataEnd,
		ReadData,
		Done
	} t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 1'b0, rst = 1'b0;

	logic enable = 1'b0, read_mode = 1'b1;
	logic [BITS - 1 : 0] received, transmitted;
	logic [BITS*ADDR_WORDS - 1 : 0] addr, word_ctr;

	wire flash_rst, flash_clk, flash_sel;
	logic flash_data_out, flash_data_in = 1'b1;

	logic word_rdy, last_word_rdy = 1'b0;
	wire bus_cycle = ~word_rdy && last_word_rdy;
	wire bus_cycle_next = word_rdy && ~last_word_rdy;

	logic word_req, last_word_req = 1'b0;
	wire bus_cycle_req = ~word_req && last_word_req;
	wire bus_cycle_req_next = word_req && ~last_word_req;


	// instantiate flash module
	flash_serial #(
		.WORD_BITS(BITS), .ADDRESS_WORDS(ADDR_WORDS),
		.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(SERIAL_CLK)
	)
	flash_mod(
		.in_clk(clk),                 // main clock
		.in_rst(rst),                 // reset
		.in_enable(enable),           // command enable
		.in_read(read_mode),          // read or write mode
		.in_addr(addr),               // address to read from
		.in_data(transmitted),        // input data
		.out_data(received),          // output data
		.out_word_ctr(word_ctr),      // currently read word index
		.out_word_finished(word_rdy), // finished reading or writing a word
		.out_next_word(word_req),     // one cycle before word finished

		// interface with flash memory pins
		.out_flash_rst(flash_rst), .out_flash_clk(flash_clk),
		.out_flash_select(flash_sel),
		.out_flash_data(flash_data_out),
		.in_flash_data(flash_data_in)
	);


	// state flip-flops
	always_ff@(posedge clk) begin
		state <= next_state;
		last_word_rdy <= word_rdy;
		last_word_req <= word_req;
	end


	// state combinatorics
	always_comb begin
		// defaults
		next_state = state;

		enable = 1'b0;
		read_mode = 1'b1;
		rst = 1'b0;
		transmitted = 1'b0;

		case(state)
			Reset: begin
				rst = 1'b1;
				next_state = WriteData;
				//next_state = ReadData;
			end

			WriteData: begin
				enable = 1'b1;
				read_mode = 1'b0;
				transmitted = 8'h71;
				addr = 16'h1281;

				if(bus_cycle_req_next == 1'b1) begin
					enable = 1'b0;
					next_state = WriteDataEnd;
				end
			end

			WriteDataEnd: begin
				if(bus_cycle/*_next*/ == 1'b1)
					next_state = ReadData;
			end

			ReadData: begin
				enable = 1'b1;
				addr = 16'h1281;

				if(bus_cycle_next == 1'b1) begin
					next_state = Done;
				end
			end

			Done: begin
			end
		endcase
	end



	// run simulation
	integer iter;

	initial begin
		$dumpfile("flash_tb.vcd");
		$dumpvars(0, flash_tb);

		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			clk = !clk;
		end

		$dumpflush();
	end


	// output
	always@(flash_clk) begin
		$display("t=%0t: state=%s, ", $time, state.name(),
			"flash: rst=%b, clk=%b, sel=%b, ", flash_rst, flash_clk, flash_sel,
			"ctr=%x, tx=%x, rx=%x", word_ctr, flash_data_out, flash_data_in);
	end


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, state=%s, ", $time, clk, state.name(),
				"enable=%b, ", enable,
				"rx=%x", received);
		end
	end

endmodule
