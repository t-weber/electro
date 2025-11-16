/**
 * serial oled testbench
 * @author Tobias Weber
 * @date 19-may-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -D__IN_SIMULATION__ -o oled_serial_tb ../lib/comm/serial_2wire.sv ../lib/clock/clkgen.sv ../lib/display/oled_serial.sv oled_serial_tb.sv
 * ./oled_serial_tb
 * gtkwave oled_serial_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module oled_serial_tb;
	localparam VERBOSE       = 1;
	localparam ITERS         = 300;
	localparam MAIN_CLK      = 1_000_000;
	localparam SERIAL_CLK    = 0_400_000;
	localparam SCREEN_WIDTH  = 4;
	localparam SCREEN_HEIGHT = 4;


	logic clk = 0, rst = 0;
	logic lcd_rst, lcd_clk, lcd_serial;

	oled_serial #(.SERIAL_BITS(8),
		.SCREEN_WIDTH(SCREEN_WIDTH), .SCREEN_HEIGHT(SCREEN_HEIGHT),
		.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(SERIAL_CLK))
	oled_mod (.in_clk(clk), .in_rst(rst),
		.in_pixels(8'b1100_0011),
		.inout_serial_clk(lcd_clk), .inout_serial(lcd_serial));


	// run simulation
	integer iter;

	initial begin
		$dumpfile("oled_serial_tb.vcd");
		$dumpvars(0, oled_serial_tb);

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
