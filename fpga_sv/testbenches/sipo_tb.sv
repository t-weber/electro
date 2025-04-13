/**
 * test for sipo module
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 13-april-2025
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o sipo_tb ../mem/sipo.sv sipo_tb.sv
 * ./sipo_tb
 * gtkwave sipo_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns


module sipo_tb;
	localparam ITERS = 20;
	localparam BITS  = 8;


	typedef enum bit [3 : 0]
	{
		Reset,
		Bit1, Bit2, Bit3, Bit4,
		Bit5, Bit6, Bit7, Bit8,
		Finished, Finished2
	} t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 1'b0, rst = 1'b0;
	logic serial_data;
	logic [BITS - 1 : 0] parallel_data;


	sipo #(
		.BITS(BITS), .SHIFT_RIGHT(1'b1)
	)
	sipo_mod(
		.in_clk(clk), .in_rst(rst),
		.in_serial(serial_data), .out_parallel(parallel_data)
	);


	// state flip-flops
	always_ff@(posedge clk) begin
		state <= next_state;
	end


	// state combinatorics
	always_comb begin
		// defaults
		next_state = state;
		rst = 1'b0;
		serial_data = 1'b0;

		case(state)
			Reset: begin
				$display("==== START ====");
				rst = 1'b1;
				next_state = Bit1;
			end

			Bit1: begin
				serial_data = 1'b1;
				next_state = Bit2;
			end

			Bit2: begin
				serial_data = 1'b0;
				next_state = Bit3;
			end

			Bit3: begin
				serial_data = 1'b0;
				next_state = Bit4;
			end

			Bit4: begin
				serial_data = 1'b1;
				next_state = Bit5;
			end

			Bit5: begin
				serial_data = 1'b0;
				next_state = Bit6;
			end

			Bit6: begin
				serial_data = 1'b0;
				next_state = Bit7;
			end

			Bit7: begin
				serial_data = 1'b1;
				next_state = Bit8;
			end

			Bit8: begin
				serial_data = 1'b0;
				next_state = Finished;
			end

			Finished: begin
				next_state = Finished2;
			end

			Finished2: begin
				$display("==== FINISHED ====");
			end
		endcase
	end


	// run simulation
	integer iter;

	initial begin
		$dumpfile("sipo_tb.vcd");
		$dumpvars(0, sipo_tb);

		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			clk = !clk;
		end

		$dumpflush();
	end


	// output
	always@(clk) begin
		$display("t = %0t: clk = %b, rst = %b, state = %s, ",
			$time, clk, rst, state.name(),
			"parallel = 0x%x = 0b%b, serial = %b",
			parallel_data, parallel_data, serial_data);
	end

endmodule
