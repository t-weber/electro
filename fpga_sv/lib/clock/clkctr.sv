/**
 * generates a (slower) clock via a counter
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 19-feb-2026
 * @license see 'LICENSE' file
 */

module clkctr
#(
	// counter to flip clock signal
	parameter longint COUNTER = 10,

	// reset value of clock
	parameter CLK_INIT = 1'b1,

	parameter USE_RISING_EDGE = 1'b1
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_reset,

	// output clock
	output wire out_clk
);


// generate clock
logic [$clog2(COUNTER) - 1 : 0] clk_ctr;

logic clk;
assign out_clk = clk;


generate if(USE_RISING_EDGE == 1'b1) begin
	always_ff@(posedge in_clk, posedge in_reset) begin
		if(in_reset == 1'b1) begin
			clk <= CLK_INIT;
			clk_ctr <= 1'b0;
		end

		else begin
			if(clk_ctr == COUNTER - 1) begin
				clk <= ~clk;
				clk_ctr <= 1'b0;
			end else begin
				clk_ctr <= clk_ctr + 1'b1;
    	end
		end
		//$display("clk_ctr = %d", clk_ctr);
	end
end
else begin
	always_ff@(negedge in_clk, posedge in_reset) begin
		if(in_reset == 1'b1) begin
			clk <= CLK_INIT;
			clk_ctr <= 1'b0;
		end

		else begin
			if(clk_ctr == COUNTER - 1) begin
				clk <= ~clk;
				clk_ctr <= 1'b0;
			end else begin
				clk_ctr <= clk_ctr + 1'b1;
    	end
		end
		//$display("clk_ctr = %d", clk_ctr);
	end
end endgenerate

endmodule
