/**
 * generates a (slower) clock
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 22-dec-2023
 * @license see 'LICENSE' file
 */


//`define CLKGEN_ASYNC


module clkgen
#(
	// clock frequencies
	parameter longint MAIN_CLK_HZ = 50_000_000,
	parameter longint CLK_HZ      = 10_000,

	// reset value of clock
	parameter bit CLK_INIT  = 1'b0,
	parameter bit CLK_SHIFT = 1'b0
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
	if(CLK_INIT != CLK_SHIFT) begin
		// same frequency, just output main clock
		assign out_clk = in_clk;
	end else begin
		// same frequency, but inverted
		// avoid gating the clock as this causes glitches
		//assign out_clk = ~in_clk;

		logic clk = CLK_INIT;
		assign out_clk = clk;

		// output a signal from a flip-flop instead of a gate
		always_ff@(/*posedge*/ in_clk
`ifdef CLKGEN_ASYNC
			// asynchronous reset
			, in_rst
`endif
		) begin
			if(in_rst == 1'b1) begin
				clk <= CLK_INIT;
			end else begin
				clk <= ~clk;
			end
		end
	end

end else begin

	// clock counter
	localparam longint CLK_CTR_MAX     = MAIN_CLK_HZ / CLK_HZ / 2 - 1;
	localparam longint CLK_CTR_SHIFTED = MAIN_CLK_HZ / CLK_HZ / 2 - MAIN_CLK_HZ / CLK_HZ / 4;

	logic [$clog2(CLK_CTR_MAX) : 0] clk_ctr = 0;


	// output clock
	logic clk = CLK_INIT;
	assign out_clk = clk;

	always_ff@(posedge in_clk
`ifdef CLKGEN_ASYNC
		// asynchronous reset
		, in_rst
`endif
	) begin
		// reset
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
				clk <= ~clk;
			end
			else begin
				clk_ctr <= $size(clk_ctr)'(clk_ctr + 1'b1);
			end
		end
	end

end
endgenerate

endmodule
