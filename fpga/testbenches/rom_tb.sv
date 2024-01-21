/**
 * rom testbench (using roms from the genrom tool)
 * @author Tobias Weber
 * @date 21-jan-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o rom_tb rom.sv rom_tb.sv
 * ./rom_tb
 */


`timescale 1ns / 1ns

module rom_tb;
	localparam ADDRBITS = 3;
	localparam DATABITS = 8;

	logic [ADDRBITS-1 : 0] addr;
	logic [DATABITS-1 : 0] data;


	// instantiate rom
	rom #(.NUM_PORTS(1))
		rom_mod(.in_addr(addr), .out_data(data));


	initial begin
		for(int i=0; i<4; ++i)
		begin
			addr <= i;
			#1;
			$display("addr=%b: %b (%h)", addr, data, data);
		end
	end

endmodule
