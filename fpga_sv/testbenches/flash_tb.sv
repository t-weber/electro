/**
 * serial flash memory testbench
 * @author Tobias Weber
 * @date 10-aug-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -D__IN_SIMULATION__ -o flash_tb ../mem/flash_serial.sv ../comm/serial.sv ../clock/clkgen.sv flash_tb.sv
 * ./flash_tb
 * gtkwave flash_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module flash_tb;
	localparam VERBOSE    = 1;
	localparam ITERS      = 512;

	localparam BITS       = 8;
	localparam ADDR_WORDS = 2;

	localparam MAIN_CLK   = 1_000_000;
	localparam SERIAL_CLK = 250_000;


	typedef enum bit [1 : 0] { Reset, ReadData } t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 1'b0, rst = 1'b0;

	logic enable;
	logic [BITS - 1 : 0] received;
	logic [BITS*ADDR_WORDS - 1 : 0] addr;

	logic flash_rst, flash_clk, flash_sel;
	logic flash_data_out, flash_data_in = 1'b1;


	// instantiate flash module
	flash_serial #(
		.WORD_BITS(BITS), .ADDRESS_WORDS(ADDR_WORDS),
		.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(SERIAL_CLK)
	)
	flash_mod(
		.in_clk(clk), .in_rst(rst),
		.in_enable(enable), .in_read(1'b1),
		.in_addr(addr), .in_data(BITS'(0)),
		.out_data(received),

		.out_flash_rst(flash_rst), .out_flash_clk(flash_clk),
		.out_flash_select(flash_sel),
		.out_flash_data(flash_data_out),
		.in_flash_data(flash_data_in)
	);


	// state flip-flops
	always_ff@(posedge clk) begin
		state <= next_state;
	end


	// state combinatorics
	always_comb begin
		// defaults
		next_state = state;

		enable = 1'b0;
		rst = 1'b0;

		case(state)
			Reset: begin
				rst = 1'b1;
				next_state = ReadData;
			end

			ReadData: begin
				enable = 1'b1;
				addr = 16'h1234;
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


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, state=%s, ", $time, clk, state.name(),
				"enable=%b, ", enable,
				"rx=%x", received);
		end
	end

endmodule
