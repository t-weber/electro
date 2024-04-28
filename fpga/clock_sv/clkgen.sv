/**
 * generates a (slower) clock
 * @author Tobias Weber
 * @date 22-dec-2023
 * @license see 'LICENSE' file
 */


module clkgen
#(
	// clock frequencies
	parameter MAIN_CLK_HZ = 50_000_000,
	parameter CLK_HZ      = 10_000,

	// reset value of clock
	parameter CLK_INIT    = 0,
	parameter CLK_SHIFT   = 0
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// output clock
	output wire out_clk
);



// clock counter
localparam CLK_CTR_MAX     = MAIN_CLK_HZ / CLK_HZ / 2 - 1;
localparam CLK_CTR_SHIFTED = MAIN_CLK_HZ / CLK_HZ / 4;
int clk_ctr = 0;


// output clock
reg clk = CLK_INIT;
assign out_clk = clk;



always_ff@(posedge in_clk, posedge in_rst) begin
	// asynchronous reset
	if(in_rst == 1) begin
		if(CLK_SHIFT == 1) begin
			clk_ctr <= CLK_CTR_SHIFTED;
		end else begin
			clk_ctr <= 0;
		end
		clk <= CLK_INIT;
	end

	// clock
	else if(in_clk == 1) begin
		if(clk_ctr == CLK_CTR_MAX) begin
			clk_ctr <= 0;
			clk <= !clk;
		end
		else begin
			clk_ctr <= clk_ctr + 1;
		end
	end
end

endmodule
