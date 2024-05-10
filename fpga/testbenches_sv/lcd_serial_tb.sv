/**
 * serial lcd testbench
 * @author Tobias Weber
 * @date 4-may-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -D__IN_SIMULATION__ -o lcd_serial_tb ../comm_sv/serial.sv ../clock_sv/clkgen.sv ../display_sv/testpattern.sv ../display_sv/video_serial.sv lcd_serial_tb.sv
 * ./lcd_serial_tb
 * gtkwave lcd_serial_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module lcd_serial_tb;
	localparam VERBOSE       = 1;
	localparam ITERS         = 300;
	localparam MAIN_CLK      = 1_000_000;
	//localparam SERIAL_CLK    = 0_250_000;
	localparam SERIAL_CLK    = 0_500_000;
	//localparam SERIAL_CLK    = 1_000_000;
	localparam SCREEN_WIDTH  = 4;
	localparam SCREEN_HEIGHT = 4;


	logic clk = 0, rst = 0;
	logic lcd_rst, lcd_clk, lcd_serial;

	video_serial #(.SERIAL_BITS(8), .PIXEL_BITS(16),
		.SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
		.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(SERIAL_CLK))
	lcd_mod (.in_clk(clk), .in_rst(rst),
		.in_pixel(16'b0010_1010_0000_0101), .out_vid_rst(lcd_rst),
		.out_vid_serial_clk(lcd_clk), .out_vid_serial(lcd_serial));


	// run simulation
	integer iter;

	initial begin
		$dumpfile("lcd_serial_tb.vcd");
		$dumpvars(0, lcd_serial_tb);

		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			clk = !clk;
		end

		$dumpflush();
	end


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, lcd_clk=%b, lcd_serial=%b",
				$time, clk, lcd_clk, lcd_serial);
		end
	end

endmodule
