/**
 * serial controller testbench
 * @author Tobias Weber
 * @date 1-may-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -D __IN_SIMULATION__ -o serial_async_tx_tb ../comm/serial_async_tx.sv ../clock/clkgen.sv serial_async_tx_tb.sv
 * ./serial_async_tx_tb
 * gtkwave serial_async_tx_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module serial_async_tx_tb;
	localparam VERBOSE    = 1;
	localparam ITERS      = 350;

	localparam BITS       = 8;
	localparam MAIN_CLK   = 1_000_000;
	localparam SERIAL_CLK = 250_000;


	typedef enum bit [1 : 0] { Reset, WriteData, NextData, Idle } t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 0, rst = 0, mod_rst = 0;
	logic enable, ready, serial_out;
	logic [BITS-1 : 0] data;

	logic byte_finished, last_byte_finished = 0;
	wire bus_cycle = byte_finished && ~last_byte_finished;


	// data
	localparam NUM_BYTES = 4;
	logic [NUM_BYTES][BITS-1 : 0] data_tosend = { 8'hff, 8'h11, 8'h01, 8'h10 };

	// data byte counter
	logic [$clog2(NUM_BYTES) : 0] byte_ctr = 0, next_byte_ctr = 0;


	// instantiate serial module
	serial_async_tx #(
		.BITS(BITS), .LOWBIT_FIRST(1),
		.MAIN_CLK_HZ(MAIN_CLK),
		.SERIAL_CLK_HZ(SERIAL_CLK)
	)
	serial_mod(
		.in_clk(clk), .in_rst(mod_rst),
		.in_enable(enable), .in_parallel(data),
		.out_serial(serial_out), .out_next_word(byte_finished),
		.out_ready(ready)
	);


	// state flip-flops
	always_ff@(posedge clk, posedge rst) begin
		// reset
		if(rst == 1) begin
			state <= Reset;
			byte_ctr <= 0;
			last_byte_finished <= 0;
		end

		// clock
		else if(clk == 1) begin
			state <= next_state;
			byte_ctr <= next_byte_ctr;
			last_byte_finished <= byte_finished;
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
				next_state = WriteData;
			end

			WriteData: begin
				enable = 1;
				data = data_tosend[byte_ctr];

				if(bus_cycle == 1'b1)
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
		$dumpfile("serial_async_tx_tb.vcd");
		$dumpvars(0, serial_async_tx_tb);

		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			clk = !clk;
		end

		$dumpflush();
	end


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, state=%s, ",
				$time, clk, state.name(),
				"next=%b, ready=%b, enable=%b, ", byte_finished, ready, enable,
				"data=%x, tx=%b", data, serial_out);
		end
	end

endmodule
