/**
 * test for piso module
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 13-april-2025
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o piso_tb ../mem/piso.sv piso_tb.sv
 * ./piso_tb
 * gtkwave piso_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns


module piso_tb;
	localparam ITERS = 32;
	localparam BITS  = 8;


	typedef enum bit [2 : 0]
	{
		Reset, Input, Output
	} t_state;
	t_state state = Reset, next_state = Reset;


	logic clk = 1'b0, rst = 1'b0;
	logic [BITS - 1 : 0] parallel_data = BITS'(8'b10010011);
	logic capture = 1'b0;
	logic serial_data;


	piso #(
		.BITS(BITS), .SHIFT_RIGHT(1'b1)
	)
	piso_mod(
		.in_clk(clk), .in_rst(rst),
		.in_parallel(parallel_data), .in_capture(capture),
		.in_rotate(1'b0),
		.out_serial(serial_data)
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
		capture = 1'b0;

		case(state)
			Reset: begin
				$display("==== START ====");
				rst = 1'b1;
				next_state = Input;
			end

			Input: begin
				capture = 1'b1;
				next_state = Output;
			end

			Output: begin
			end
		endcase
	end


	// run simulation
	integer iter;

	initial begin
		$dumpfile("piso_tb.vcd");
		$dumpvars(0, piso_tb);

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
