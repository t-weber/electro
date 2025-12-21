/**
 * generates a clock and timing pulses
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 21-dec-2025
 * @license see 'LICENSE' file
 */


module clkpulsegen
#(
	// clock frequencies
	parameter longint MAIN_CLK_HZ = 50_000_000,
	parameter longint CLK_HZ      = 10_000,

	// reset value of clock
	parameter bit CLK_INIT = 1'b0
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// output clock
	output wire out_clk,

	// output clock edges
	output wire out_re, out_fe
);


// clock counter half and full periods
localparam longint CLK_CTR_HALF = MAIN_CLK_HZ / CLK_HZ / 2;
//localparam longint CLK_CTR_FULL = MAIN_CLK_HZ / CLK_HZ;
localparam longint CLK_CTR_FULL = CLK_CTR_HALF * 2;

// clock counters for half and full period
logic [$clog2(CLK_CTR_HALF - 1) : 0] clk_ctr_half = 0;
logic [$clog2(CLK_CTR_FULL - 1) : 0] clk_ctr_full = 0;


// output clock
logic clk = CLK_INIT;
assign out_clk = clk;


// generate clock
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		clk_ctr_half <= 0;
		clk_ctr_full <= 0;
		clk <= CLK_INIT;
	end

	// clock
	else begin
		if(clk_ctr_half == CLK_CTR_HALF - 1) begin
			clk_ctr_half <= 1'b0;
			clk <= ~clk;
		end
		else begin
			clk_ctr_half <= $size(clk_ctr_half)'(clk_ctr_half + 1'b1);
		end

		if(clk_ctr_full == CLK_CTR_FULL - 1) begin
			clk_ctr_full <= 1'b0;
		end
		else begin
			clk_ctr_full <= $size(clk_ctr_full)'(clk_ctr_full + 1'b1);
		end
	end
end


// output edges
logic re = 1'b0, fe = 1'b0;


generate if(CLK_INIT == 1'b0) begin
	assign out_re = re;
	assign out_fe = fe;
end else begin
	assign out_re = fe;
	assign out_fe = re;
end endgenerate

// generate edge pulses
always@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		re <= 1'b0;
		fe <= 1'b0;
	end

	// clock
	else begin
		re <= 1'b0;
		fe <= 1'b0;

		if(clk_ctr_full == CLK_CTR_HALF - 1)
			re <= 1'b1;
		else if(clk_ctr_full == CLK_CTR_FULL - 1)
			fe <= 1'b1;
	end
end


endmodule
