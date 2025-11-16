/**
 * ram testbench
 * @author Tobias Weber
 * @date 21-feb-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o ram_2port_tb ../lib/mem/ram_2port.sv ram_2port_tb.sv
 * ./ram_2port_tb
 */


`timescale 1ns / 1ns


module ram_tb;
	localparam ADDR_BITS = 8;
	localparam DATA_BITS = 8;

	logic clock = 0;
	logic reset = 0;

	// port 1
	logic read_enable_1, write_enable_1;
	logic [ADDR_BITS-1 : 0] addr_1;
	logic [DATA_BITS-1 : 0] data_1, out_data_1;

	// port 2
	logic [ADDR_BITS-1 : 0] addr_2;
	logic [DATA_BITS-1 : 0] out_data_2;


	// instantiate ram
	ram_2port #(.ADDR_BITS(ADDR_BITS), .WORD_BITS(DATA_BITS))
		ram_mod(
			.in_rst(reset),

			// port 1 (reading and writing)
			.in_clk_1(clock),
			.in_read_ena_1(read_enable_1), .in_write_ena_1(write_enable_1),
			.in_addr_1(addr_1), .in_data_1(data_1), .out_data_1(out_data_1),

			// port 2 (reading)
			.in_clk_2(clock),
			.in_read_ena_2(1'b1), .in_write_ena_2(1'b0),
			.in_addr_2(addr_2), .in_data_2(), .out_data_2(out_data_2)
		);


	initial begin
		addr_1 <= 8'h00;
		read_enable_1 <= 1'b1;
		write_enable_1 <= 1'b0;
		addr_2 <= 8'h12;

		$display("-- RESET --");
		reset <= 1'b1;
		#1; clock <= ~clock;  // 0 -> 1
		#1; clock <= ~clock;  // 1 -> 0

		$display("-- WRITE DATA --");
		reset <= 1'b0;
		addr_1 <= 8'h12;
		read_enable_1 <= 1'b0;
		write_enable_1 <= 1'b1;
		data_1 <= 8'hab;
		#1; clock <= ~clock;  // 0 -> 1
		#1; clock <= ~clock;  // 1 -> 0

		$display("-- READ BACK DATA --");
		read_enable_1 <= 1'b1;
		write_enable_1 <= 1'b0;
		data_1 <= 8'h00;
		addr_1 <= 8'h12;
		#1; clock <= ~clock;  // 0 -> 1
		#1; clock <= ~clock;  // 1 -> 0

		$display("-- READ OTHER DATA --");
		read_enable_1 <= 1'b1;
		write_enable_1 <= 1'b0;
		data_1 <= 8'h00;
		addr_1 <= 8'h00;
		#1; clock <= ~clock;  // 0 -> 1
		#1; clock <= ~clock;  // 1 -> 0

		$display("-- READ BACK DATA --");
		read_enable_1 <= 1'b1;
		write_enable_1 <= 1'b0;
		data_1 <= 8'h00;
		addr_1 <= 8'h12;
		#1; clock <= ~clock;  // 0 -> 1
		#1; clock <= ~clock;  // 1 -> 0

		$display("-- FINISHED --");
		read_enable_1 <= 1'b0;
		write_enable_1 <= 1'b0;
		data_1 <= 8'h00;
		addr_1 <= 8'h00;
		#1; clock <= ~clock;  // 0 -> 1
		#1; clock <= ~clock;  // 1 -> 0
	end


	// debug output
	always@(clock) begin
		$display("clk=%b; ", clock,
		"addr_1=%b (%h), in_1: %b (%h), out_1: %b (%h); ",
		addr_1, addr_1, data_1, data_1, out_data_1, out_data_1,
		"addr_2=%b (%h), out_2: %b (%h)",
		addr_2, addr_2, out_data_2, out_data_2);
	end

endmodule
