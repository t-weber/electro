/**
 * ram testbench
 * @author Tobias Weber
 * @date 21-feb-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o ram_tb ../lib/mem/ram.sv ram_tb.sv
 * ./ram_tb
 */


`timescale 1ns / 1ns


module ram_tb;
	localparam ADDR_BITS = 8;
	localparam DATA_BITS = 8;

	logic reset = 0;
	logic [1] clock = 0;
	logic [1] read_enable, write_enable;
	logic [1][ADDR_BITS-1 : 0] addr;
	logic [1][DATA_BITS-1 : 0] data, out_data;


	// instantiate ram
	ram #(.NUM_PORTS(1), .ADDR_BITS(ADDR_BITS), .WORD_BITS(DATA_BITS))
		ram_mod(
			.in_clk(clock), .in_rst(reset),
			.in_read_ena(read_enable), .in_write_ena(write_enable),
			.in_addr(addr),
			.in_data(data), .out_data(out_data)
		);


	initial begin
		addr <= 8'h00;
		read_enable[0] <= 1'b1;
		write_enable[0] <= 1'b0;

		$display("-- RESET --");
		reset <= 1'b1;
		#1; clock[0] <= ~clock[0];  // 0 -> 1
		#1; clock[0] <= ~clock[0];  // 1 -> 0

		$display("-- WRITE DATA --");
		reset <= 1'b0;
		addr <= 8'h12;
		read_enable[0] <= 1'b0;
		write_enable[0] <= 1'b1;
		data <= 8'hab;
		#1; clock[0] <= ~clock[0];  // 0 -> 1
		#1; clock[0] <= ~clock[0];  // 1 -> 0

		$display("-- READ BACK DATA --");
		read_enable[0] <= 1'b1;
		write_enable[0] <= 1'b0;
		data <= 8'h00;
		addr <= 8'h12;
		#1; clock[0] <= ~clock[0];  // 0 -> 1
		#1; clock[0] <= ~clock[0];  // 1 -> 0

		$display("-- READ OTHER DATA --");
		read_enable[0] <= 1'b1;
		write_enable[0] <= 1'b0;
		data <= 8'h00;
		addr <= 8'hff;
		#1; clock[0] <= ~clock[0];  // 0 -> 1
		#1; clock[0] <= ~clock[0];  // 1 -> 0

		$display("-- READ BACK DATA --");
		read_enable[0] <= 1'b1;
		write_enable[0] <= 1'b0;
		data <= 8'h00;
		addr <= 8'h12;
		#1; clock[0] <= ~clock[0];  // 0 -> 1
		#1; clock[0] <= ~clock[0];  // 1 -> 0

		$display("-- FINISHED --");
		read_enable[0] <= 1'b0;
		write_enable[0] <= 1'b0;
		data <= 8'h00;
		addr <= 8'h00;
		#1; clock[0] <= ~clock[0];  // 0 -> 1
		#1; clock[0] <= ~clock[0];  // 1 -> 0
	end


	// debug output
	always@(clock[0]) begin
		$display("clk=%b, addr=0b%b (0x%h), ",
			clock[0], addr, addr,
			"in: 0b%b (0x%h), ",
			data, data,
			"out: 0b%b (0x%h).",
			out_data, out_data);
	end

endmodule
