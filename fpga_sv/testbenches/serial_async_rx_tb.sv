/**
 * serial controller testbench
 * @author Tobias Weber
 * @date 9-june-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o serial_async_rx_tb ../comm/serial_async_rx.sv ../comm/serial_async_tx.sv ../clock/clkgen.sv serial_async_rx_tb.sv
 * ./serial_async_rx_tb
 * gtkwave serial_async_rx_tb.vcd --rcvar "do_initial_zoom_fit yes"
 *
 * optional: -D __IN_SIMULATION__
 */


`timescale 1ns / 1ns

module serial_async_rx_tb;
	localparam VERBOSE    = 1'b0;

	localparam BITS          = 8;
	localparam PARITY        = 1;
	localparam MAIN_CLK      = 80_000;
	localparam SERIAL_TX_CLK = 10_000;
	localparam SERIAL_RX_CLK = 10_000;

	logic clk = 1'b0, rst = 1'b0;

	// random data
	localparam NUM_BYTES = 256;
	logic [NUM_BYTES][BITS-1 : 0] data_tosend;

	initial begin
		foreach(data_tosend[idx])
			data_tosend[idx] = $urandom_range(0, 255);
	end

	// data byte counter
	logic [$clog2(NUM_BYTES) : 0] byte_ctr = 0, next_byte_ctr = 0;


	// --------------------------------------------------------------------
	// transmitter
	// --------------------------------------------------------------------
	logic rst_tx, enable_tx;
	logic ready_tx;
	logic serial_tx;
	logic [BITS-1 : 0] data_tx;

	logic byte_finished_tx, last_byte_finished_tx = 1'b0;
	wire bus_cycle_tx = byte_finished_tx && ~last_byte_finished_tx;


	// transmitter states
	typedef enum bit [1 : 0] { Reset, WriteData, NextData, Idle } t_state_tx;
	t_state_tx state_tx = Reset, next_state_tx = Reset;


	// instantiate serial transmitter
	serial_async_tx #(
		.BITS(BITS), .LOWBIT_FIRST(1'b1),
		.PARITY_BITS(PARITY),
		.MAIN_CLK_HZ(MAIN_CLK),
		.SERIAL_CLK_HZ(SERIAL_TX_CLK)
	)
	serial_tx_mod(
		.in_clk(clk), .in_rst(rst_tx),
		.in_enable(enable_tx), .in_parallel(data_tx),
		.out_serial(serial_tx), .out_next_word(byte_finished_tx),
		.out_ready(ready_tx)
	);


	// tx state flip-flops
	always_ff@(posedge clk, posedge rst) begin
		// reset
		if(rst == 1'b1) begin
			state_tx <= Reset;
			byte_ctr <= 0;
			last_byte_finished_tx <= 0;
		end

		// clock
		else begin
			state_tx <= next_state_tx;
			byte_ctr <= next_byte_ctr;
			last_byte_finished_tx <= byte_finished_tx;
		end
	end


	// tx state combinatorics
	always_comb begin
		// defaults
		next_state_tx = state_tx;
		next_byte_ctr = byte_ctr;

		enable_tx = 1'b0;
		rst_tx = 1'b0;
		data_tx = 0;

		case(state_tx)
			Reset: begin
				rst_tx = 1'b1;
				next_state_tx = WriteData;
			end

			WriteData: begin
				enable_tx = 1'b1;
				data_tx = data_tosend[byte_ctr];

				if(bus_cycle_tx == 1'b1) begin
					$display("Transmitted byte %d: %x", byte_ctr, data_tx);
					next_state_tx = NextData;
				end
			end

			NextData: begin
				if(ready_tx == 1'b1) begin
					if(byte_ctr + 1 == NUM_BYTES) begin
						next_state_tx = Idle;
					end else begin
						next_byte_ctr = byte_ctr + 1;
						next_state_tx = WriteData;
					end;
				end;
			end

			Idle: begin
			end
		endcase
	end
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// receiver
	// --------------------------------------------------------------------
	logic rst_rx, enable_rx;
	logic ready_rx;
	logic [BITS-1 : 0] data_rx;

	logic byte_finished_rx, last_byte_finished_rx = 1'b0;
	wire bus_cycle_rx = byte_finished_rx && ~last_byte_finished_rx;


	// receiver states
	typedef enum bit [1 : 0] { ResetRx, WaitData, ReadData, IdleRx } t_state_rx;
	t_state_rx state_rx = ResetRx, next_state_rx = ResetRx;


	// instantiate serial receiver
	serial_async_rx #(
		.BITS(BITS), .LOWBIT_FIRST(1'b1),
		.PARITY_BITS(PARITY),
		.MAIN_CLK_HZ(MAIN_CLK),
		.SERIAL_CLK_HZ(SERIAL_RX_CLK)
	)
	serial_rx_mod(
		.in_clk(clk), .in_rst(rst_rx),
		.in_enable(enable_rx), .in_serial(serial_tx),
		.out_parallel(data_rx),
		/*.out_next_word*/.out_word_finished(byte_finished_rx),
		.out_ready(ready_rx)
	);


	// rx state flip-flops
	always_ff@(posedge clk, posedge rst) begin
		// reset
		if(rst == 1'b1) begin
			state_rx <= ResetRx;
			last_byte_finished_rx <= 0;
		end

		// clock
		else begin
			state_rx <= next_state_rx;
			last_byte_finished_rx <= byte_finished_rx;
		end
	end


	// rx state combinatorics
	always_comb begin
		// defaults
		next_state_rx = state_rx;

		enable_rx = 1'b1;
		rst_rx = 1'b0;

		case(state_rx)
			ResetRx: begin
				rst_rx = 1'b1;
				next_state_rx = WaitData;
			end

			WaitData: begin
				if(bus_cycle_rx == 1'b1) begin
					$display("Received byte    %d: %x\n", byte_ctr, data_rx);
					if(data_rx != data_tosend[byte_ctr])
						$error("Invalid byte received!");
					next_state_rx = ReadData;
				end
			end

			ReadData: begin
				if(byte_ctr + 1 == NUM_BYTES)
					next_state_rx = IdleRx;
				else
					next_state_rx = WaitData;
			end

			IdleRx: begin
				enable_rx = 1'b0;
			end
		endcase
	end
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// run simulation
	initial begin
		$dumpfile("serial_async_rx_tb.vcd");
		$dumpvars(0, serial_async_rx_tb);

		while(state_tx != Idle) begin
			#1;
			clk = !clk;
		end

		$dumpflush();
	end


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, state_tx=%s, ",
				$time, clk, state_tx.name(),
				"nxt_tx=%b, nxt_rx=%b, rdy_tx=%b, rdy_rx=%b, ena_tx=%b, ",
				byte_finished_tx, byte_finished_rx, ready_tx, ready_rx, enable_tx,
				"tx=%b, data_tx=%x, data_rx=%x", serial_tx, data_tx, data_rx);
		end
	end
	// --------------------------------------------------------------------

endmodule
