/**
 * video testbench
 * @author Tobias Weber
 * @date 30-mar-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o video_tb ../display_sv/video.sv ../display_sv/testpattern.sv video_tb.sv
 * ./video_tb
 * gtkwave video_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1ns / 1ns

module video_tb;
	localparam VERBOSE    = 1;
	localparam ITERS      = 64;

	logic clk = 0, rst = 0;
	wire hsync, vsync, enable;

	wire [2 : 0] hpix, hpix_raw;
	wire [2 : 0] vpix, vpix_raw;

	wire [23 : 0] pixel;


	// instantiate modules
	video #(
		.HPIX_VISIBLE(4), .VPIX_VISIBLE(4),
		.HSYNC_START(0), .HSYNC_STOP(1), .HSYNC_DELAY(2),
		.VSYNC_START(0), .VSYNC_STOP(2), .VSYNC_DELAY(2)
	)
	video_mod(
		.in_clk(clk), .in_rst(rst),
		.in_mem(24'b0),

		.in_testpattern(1'b1),

		.out_hsync(hsync), .out_vsync(vsync),
		.out_pixel_enable(enable),

		.out_hpix(hpix), .out_vpix(vpix),
		.out_hpix_raw(hpix_raw), .out_vpix_raw(vpix_raw),

		.out_pixel(pixel)
	);


	// run simulation
	integer iter;

	initial begin
		$dumpfile("video_tb.vcd");
		$dumpvars(0, video_tb);

		clk <= 0;

		// reset
		rst <= 0;
		#1;
		clk = !clk;

		rst <= 1;
		#1;
		clk = !clk;
		$display("t=%0t: RESET", $time);

		rst <= 0;
		#1;
		clk = !clk;


		// clock
		for(iter = 0; iter < ITERS; ++iter) begin
			#1;
			clk = !clk;
		end

		$dumpflush();
	end


	// verbose output
	always@(clk) begin
		if(VERBOSE) begin
			$display("t=%0t: clk=%b, ", $time, clk,

				"hsync=%b, vsync=%b, enable=%b, ",
				hsync, vsync, enable,

				"x=%d, y=%d, xr=%d, yr=%d, ",
				hpix, vpix, hpix_raw, vpix_raw,

				"pixel=%h", pixel);
		end
	end

endmodule
