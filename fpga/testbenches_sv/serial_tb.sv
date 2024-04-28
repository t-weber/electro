/**
 * serial controller testbench
 * @author Tobias Weber
 * @date 22-dec-2023
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o serial_tb ../comm_sv/serial.sv ../clock_sv/clkgen.sv serial_tb.sv
 * ./serial_tb
 * gtkwave serial_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module serial_tb;
	localparam VERBOSE    = 0;
	localparam ITERS      = 128;

	localparam BITS       = 8;
	localparam MAIN_CLK   = 1_000_000;
	localparam SERIAL_CLK = 250_000;

	logic clk = 0, rst = 0;
	logic [BITS-1 : 0] data;
	logic [BITS-1 : 0] parallel_in;
	logic enable, ready, next;
	logic serial, serial_clk;


	// instantiate modules
	serial #(
		.BITS(BITS), .LOWBIT_FIRST(0),
		.MAIN_CLK_HZ(MAIN_CLK),
		.SERIAL_CLK_HZ(SERIAL_CLK),
		.SERIAL_CLK_INACTIVE(1)
	)
		serial_mod(
		.in_clk(clk), .in_rst(rst),
		.in_parallel(data), .in_enable(enable),
		.out_serial(serial), .out_next_word(next),
		.out_ready(ready), .out_clk(serial_clk),
		.in_serial(serial), .out_parallel(parallel_in)
	);


	// run simulation
	integer iter;

	initial begin
		$dumpfile("serial_tb.vcd");
		$dumpvars(0, serial_tb);

		clk <= 0;
		enable <= 0;

		// reset
		rst <= 0;
		#1;
		clk = !clk;

		rst <= 1;
		#1;
		clk = !clk;
		$display("t=%0t: RESET", $time);

		rst <= 0;
		#1;
		clk = !clk;


		// clock
		enable <= 1;
		data <= 8'hff;
		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			clk = !clk;
		end


		enable <= 0;
		#1;
		clk = !clk;
		#1;
		clk = !clk;

		$dumpflush();
	end


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, serial_clk=%b, ",
				$time, clk, serial_clk,
				"serial=%b, next=%b, ready=%b, enable=%b",
				serial, next, ready, enable);
		end
	end


	// output serial signal
	always@(posedge serial_clk) begin
		$display("t=%0t: serial_out=%b, parallel_in=%x, next=%b, ready=%b",
			$time, serial, parallel_in, next, ready);
	end

endmodule
