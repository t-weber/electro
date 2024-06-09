/**
 * serial controller testbench
 * @author Tobias Weber
 * @date 9-june-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -D __IN_SIMULATION__ -o serial_async_rx_tb ../comm/serial_async_rx.sv ../comm/serial_async_tx.sv ../clock/clkgen.sv serial_async_rx_tb.sv
 * ./serial_async_rx_tb
 * gtkwave serial_async_rx_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module serial_async_rx_tb;
	localparam VERBOSE    = 1'b1;
	localparam ITERS      = 750;

	localparam BITS       = 8;
	localparam MAIN_CLK   = 80_000;
	localparam SERIAL_CLK = 10_000;


	typedef enum bit [1 : 0] { Reset, WriteData, NextData, Idle } t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 0, rst = 0, mod_rst = 0;
	logic enable_tx, enable_rx;
	logic ready_rx, ready_tx;
	logic serial_out;
	logic [BITS-1 : 0] data, parallel_out;

	logic byte_finished, last_byte_finished = 0;
	logic byte_finished_rx;
	wire bus_cycle = byte_finished && ~last_byte_finished;


	// data
	localparam NUM_BYTES = 4;
	logic [NUM_BYTES][BITS-1 : 0] data_tosend = { 8'hff, 8'h11, 8'h01, 8'h10 };

	// data byte counter
	logic [$clog2(NUM_BYTES) : 0] byte_ctr = 0, next_byte_ctr = 0;


	// instantiate serial transmitter
	serial_async_tx #(
		.BITS(BITS), .LOWBIT_FIRST(1'b1),
		.MAIN_CLK_HZ(MAIN_CLK),
		.SERIAL_CLK_HZ(SERIAL_CLK)
	)
	serial_tx_mod(
		.in_clk(clk), .in_rst(mod_rst),
		.in_enable(enable_tx), .in_parallel(data),
		.out_serial(serial_out), .out_next_word(byte_finished),
		.out_ready(ready_tx)
	);

	// instantiate serial receiver
	serial_async_rx #(
		.BITS(BITS), .LOWBIT_FIRST(1'b1),
		.MAIN_CLK_HZ(MAIN_CLK),
		.SERIAL_CLK_HZ(SERIAL_CLK)
	)
	serial_rx_mod(
		.in_clk(clk), .in_rst(mod_rst),
		.in_enable(enable_rx), .in_serial(serial_out),
		.out_parallel(parallel_out), .out_next_word(byte_finished_rx),
		.out_ready(ready_rx)
	);


	// state flip-flops
	always_ff@(posedge clk, posedge rst) begin
		// reset
		if(rst == 1'b1) begin
			state <= Reset;
			byte_ctr <= 0;
			last_byte_finished <= 0;
		end

		// clock
		else begin
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

		enable_tx = 1'b0;
		enable_rx = 1'b1;
		mod_rst = 1'b0;
		data = 0;

		case(state)
			Reset: begin
				mod_rst = 1'b1;
				next_state = WriteData;
			end

			WriteData: begin
				enable_tx = 1'b1;
				data = data_tosend[byte_ctr];

				if(bus_cycle == 1'b1)
					next_state = NextData;
			end

			NextData: begin
				if(ready_tx == 1) begin
					if(byte_ctr + 1 == NUM_BYTES) begin
						next_state = Idle;
					end else begin
						next_byte_ctr = byte_ctr + 1;
						next_state = WriteData;
					end;
				end;
			end

			Idle: begin
				enable_rx = 1'b0;
			end
		endcase
	end



	// run simulation
	integer iter;

	initial begin
		$dumpfile("serial_async_rx_tb.vcd");
		$dumpvars(0, serial_async_rx_tb);

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
				"nxt_tx=%b, nxt_rx=%b, rdy_tx=%b, rdy_rx=%b, ena_tx=%b, ",
				byte_finished, byte_finished_rx, ready_tx, ready_rx, enable_tx,
				"data=%x, tx=%b, rx=%x", data, serial_out, parallel_out);
		end
	end

endmodule
