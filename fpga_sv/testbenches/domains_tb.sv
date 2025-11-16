/**
 * clock domain synchronisation testbench (passing from fast to slow clock)
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date aug-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o domains_tb domains_tb.sv ../lib/mem/fifo.sv ../lib/clock/clkgen.sv
 * ./domains_tb
 */

`timescale 1ns / 100ps
`default_nettype /*wire*/ none  // no implicit declarations


module domains_tb;
	localparam ITERS   = 32;
	localparam VERBOSE = 1;
	localparam BITS    = 8;

	// clocks
	localparam FAST_CLK_HZ = 40_000_000;
	localparam SLOW_CLK_HZ = 10_000_000;

	logic fast_clk = 1'b0, slow_clk;
	logic rst = 1'b0;

	// data generated in fast clock domain
	logic [ BITS - 1 : 0 ] fast_data = 1'b0, slow_data;


	//
	// fast main clock
	//
	integer iter;

	initial begin
		$dumpfile("domains_tb.vcd");
		$dumpvars(0, domains_tb);

		rst <= 1'b0;
		fast_clk <= 1'b0; #1; fast_clk <= 1'b1; #1;
		rst <= 1'b1;
		fast_clk <= 1'b0; #1; fast_clk <= 1'b1; #1;
		rst <= 1'b0;

		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			fast_clk <= ~fast_clk;
		end

		$dumpflush();
	end


	//
	// generate slow clock
	//
	clkgen #(.MAIN_CLK_HZ(FAST_CLK_HZ), .CLK_HZ(SLOW_CLK_HZ), .CLK_INIT(1'b0))
	slow_clk_gen(.in_rst(rst), .in_clk(fast_clk), .out_clk(slow_clk));


	//
	// data synchronisation from fast to slow clock
	//
	fifo #(.WORD_BITS(BITS), .ADDR_BITS(8))
	clk_sync(.in_rst(rst), .in_insert(1'b1), .in_remove(1'b1),
		.in_clk_insert(fast_clk), .in_clk_remove(slow_clk),
		.in_data(fast_data), .out_back(slow_data));


	//
	// generate some data (counter)
	//
	always@(posedge fast_clk) begin
		if(rst == 1'b1)
			fast_data <= 1'b0;
		else
			fast_data <= $size(fast_data)'(fast_data + 1'b1);
	end


	//
	// printing process
	//
	generate if(VERBOSE) begin
		always@(edge fast_clk) begin
			$display("fast_clk = %b", fast_clk,
				", slow_clk = %b", slow_clk,
				", reset = %b", rst,
				", fast_data = %h", fast_data,
				", slow_data = %h", slow_data);
		end
	end endgenerate

endmodule
