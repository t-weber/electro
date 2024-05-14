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
	parameter CLK_INIT    = 1'b0,
	parameter CLK_SHIFT   = 1'b0
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// output clock
	output wire out_clk
);


generate
if(MAIN_CLK_HZ == CLK_HZ) begin

	// same frequency -> just output main clock
	if(CLK_INIT == 1'b1) begin
		if(CLK_SHIFT == 1'b1) begin
			assign out_clk = ~in_clk;
		end else begin
			assign out_clk = in_clk;
		end
	end else begin
		if(CLK_SHIFT == 1'b1) begin
			assign out_clk = in_clk;
		end else begin
			assign out_clk = ~in_clk;
		end
	end

end else begin

	// clock counter
	localparam CLK_CTR_MAX     = MAIN_CLK_HZ / CLK_HZ / 2 - 1;
	localparam CLK_CTR_SHIFTED = MAIN_CLK_HZ / CLK_HZ / 2 - MAIN_CLK_HZ / CLK_HZ / 4;
	bit [$clog2(CLK_CTR_MAX) : 0] clk_ctr = 0;


	// output clock
	reg clk = CLK_INIT;
	assign out_clk = clk;

	always_ff@(posedge in_clk, posedge in_rst) begin
		// asynchronous reset
		if(in_rst == 1'b1) begin
			if(CLK_SHIFT == 1'b1) begin
				clk_ctr <= CLK_CTR_SHIFTED;
			end else begin
				clk_ctr <= 0;
			end
			clk <= CLK_INIT;
		end

		// clock
		else begin
			if(clk_ctr == CLK_CTR_MAX) begin
				clk_ctr <= 1'b0;
				clk <= !clk;
			end
			else begin
				clk_ctr <= clk_ctr + 1;
			end
		end
	end

end
endgenerate

endmodule
