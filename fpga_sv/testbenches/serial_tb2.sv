/**
 * serial controller testbench
 * @author Tobias Weber
 * @date 1-may-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o serial_tb2 ../comm/serial.sv ../clock/clkgen.sv serial_tb2.sv
 * ./serial_tb2
 * gtkwave serial_tb2.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module serial_tb2;
	localparam VERBOSE    = 0;
	localparam ITERS      = 1024;

	localparam BITS       = 8;
	localparam MAIN_CLK   = 1_000_000;
	localparam SERIAL_CLK = 250_000;


	typedef enum bit [1 : 0] { Reset, WriteData, NextData, Idle } t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 0, rst = 0, mod_rst = 0;

	logic enable, ready;
	logic serial, serial_clk;

	logic [BITS-1 : 0] data_tx, data_rx, saved;

	logic byte_finished, last_byte_finished = 0;
	wire bus_cycle = byte_finished && ~last_byte_finished;
	wire bus_cycle_next = ~byte_finished && last_byte_finished;


	// data
	localparam NUM_BYTES = 4;
	logic [NUM_BYTES][BITS-1 : 0] data_tosend = { 8'hff, 8'h11, 8'h01, 8'h10 };

	// data byte counter
	reg [$clog2(NUM_BYTES) : 0] byte_ctr = 0, next_byte_ctr = 0;


	// instantiate serial module
	serial #(
		.BITS(BITS), .LOWBIT_FIRST(1),
		.MAIN_CLK_HZ(MAIN_CLK),
		.SERIAL_CLK_HZ(SERIAL_CLK),
		.SERIAL_CLK_INACTIVE(0)
	)
	serial_mod(
		.in_clk(clk), .in_rst(mod_rst),
		.in_parallel(data_tx), .in_enable(enable),
		.out_serial(serial), .out_next_word(byte_finished),
		.out_ready(ready), .out_clk(serial_clk),
		.in_serial(serial), .out_parallel(data_rx)
	);


	// state flip-flops
	always_ff@(posedge clk, posedge rst) begin
		// reset
		if(rst == 1) begin
			state <= Reset;
			byte_ctr <= 0;
			last_byte_finished <= 0;

			saved <= 0;
		end

		// clock
		else if(clk == 1) begin
			state <= next_state;
			byte_ctr <= next_byte_ctr;
			last_byte_finished <= byte_finished;

			if(bus_cycle_next)
				saved <= data_rx;
		end
	end


	// state combinatorics
	always_comb begin
		// defaults
		next_state = state;
		next_byte_ctr = byte_ctr;

		enable = 0;
		mod_rst = 0;
		data_tx = 0;

		case(state)
			Reset: begin
				mod_rst = 1;
				next_state = WriteData;
			end

			WriteData: begin
				enable = 1;
				data_tx = data_tosend[byte_ctr];

				if(bus_cycle == 1)
					next_state = NextData;
			end

			NextData: begin
				//if(ready == 1) begin
					if(byte_ctr + 1 == NUM_BYTES) begin
						next_state = Idle;
					end else begin
						next_byte_ctr = byte_ctr + 1;
						next_state = WriteData;
					end;
				//end;
			end

			Idle: begin
			end
		endcase
	end



	// run simulation
	integer iter;

	initial begin
		$dumpfile("serial_tb2.vcd");
		$dumpvars(0, serial_tb2);

		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			clk = !clk;
		end

		$dumpflush();
	end


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, serial_clk=%b, state=%s, ",
				$time, clk, serial_clk, state.name(),
				"serial=%b, next=%b, ready=%b, enable=%b, ",
				serial, byte_finished, ready, enable,
				"tx=%x, rx=%x",
				data_tx, data_rx);
		end
	end


	// output serial signal
	always@(negedge serial_clk) begin
		$display("t=%0t: serial_out=%b, tx=%x, rx=%x, saved=%x, next=%b, ready=%b, ctr=%d",
			$time, serial, data_tx, data_rx, saved, byte_finished, ready, byte_ctr);
	end

endmodule
