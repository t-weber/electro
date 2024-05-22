/**
 * serial controller testbench
 * @author Tobias Weber
 * @date 1-may-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o serial_2wire_tb ../comm/serial_2wire.sv ../clock/clkgen.sv serial_2wire_tb.sv
 * ./serial_2wire_tb
 * gtkwave serial_2wire_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module serial_2wire_tb;
	localparam VERBOSE    = 1;
	localparam ITERS      = 775;

	localparam BITS       = 8;
	localparam MAIN_CLK   = 1_000_000;
	localparam SERIAL_CLK = 250_000;


	typedef enum bit [2 : 0]
	{
		Reset, Idle,
		WriteAddr, WriteData, NextAddr
	} t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 0, rst = 0, mod_rst = 0;

	logic enable, ready, error;
	logic serial, serial_clk;

	logic [BITS-1 : 0] data;
	logic [BITS-1 : 0] received;
	logic [BITS-1 : 0] saved;

	logic byte_finished, last_byte_finished = 0;
	wire bus_cycle = byte_finished && ~last_byte_finished;
	wire bus_cycle_next = ~byte_finished && last_byte_finished;


	// data
	localparam NUM_BYTES = 4;
	logic [NUM_BYTES][BITS-1 : 0] data_tosend =
	{
		8'h01, 8'h11,
		8'h02, 8'h22
	};

	// data byte counter
	reg [$clog2(NUM_BYTES) : 0] byte_ctr = 0, next_byte_ctr = 0;


	// instantiate serial module
	serial_2wire #(
		.BITS(BITS), .LOWBIT_FIRST(0), .IGNORE_ERROR(1),
		.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK)
	)
	serial_mod(
		.in_clk(clk), .in_rst(mod_rst), .out_err(error),
		.in_enable(enable), .in_write(1'b1), .out_ready(ready),
		.in_addr_write(8'b10101010), .in_addr_read(8'b10101011),
		.inout_serial_clk(serial_clk), .inout_serial(serial),
		.in_parallel(data), .out_parallel(received),
		.out_next_word(byte_finished)
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
				saved <= received;
		end
	end


	// state combinatorics
	always_comb begin
		// defaults
		next_state = state;
		next_byte_ctr = byte_ctr;

		enable = 0;
		mod_rst = 0;
		data = 0;

		case(state)
			Reset: begin
				mod_rst = 1;
				next_state = WriteAddr;
			end

			WriteAddr: begin
				enable = 1;
				data = data_tosend[byte_ctr];

				if(bus_cycle == 1)
					next_state = WriteData;
			end

			WriteData: begin
				enable = 1;
				data = data_tosend[byte_ctr + 1'b1];

				if(bus_cycle == 1)
					next_state = NextAddr;
			end

			NextAddr: begin
				if(ready == 1) begin
					if(byte_ctr + 2 == NUM_BYTES) begin
						next_state = Idle;
					end else begin
						next_byte_ctr = byte_ctr + 1;
						next_state = WriteAddr;
					end;
				end;
			end

			Idle: begin
			end
		endcase
	end



	// run simulation
	integer iter;

	initial begin
		$dumpfile("serial_2wire_tb.vcd");
		$dumpvars(0, serial_2wire_tb);

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
				data, received);
		end
	end


	// output serial signal
	/*always@(negedge serial_clk) begin
		$display("t=%0t: serial_out=%b, tx=%x, rx=%x, saved=%x, next=%b, ready=%b, ctr=%d",
			$time, serial, data, received, saved, byte_finished, ready, byte_ctr);
	end*/

endmodule
