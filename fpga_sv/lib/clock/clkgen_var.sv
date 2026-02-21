/**
 * generates a (slower) clock with a variable frequency
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-nov-2023, 24-may-2025, 15-feb-2026
 * @license see 'LICENSE' file
 */

module clkgen_var
#(
	// clock rates
	parameter longint MAIN_HZ = 50_000_000,
	parameter int     HZ_BITS = 32  // ceil(log2(MAIN_HZ)) 
 )
(
	// generated clock frequency
	input wire [HZ_BITS - 1 : 0] in_clk_hz,
	input wire in_clk_shift,

	// reset value of clock
	input wire in_clk_init,

	// main clock and reset
	input wire in_clk,
	input wire in_reset,

	// output clock
	output wire out_clk
);


function logic [HZ_BITS - 1 : 0]
get_clk_shift(logic is_shifted, logic [HZ_BITS - 1 : 0] slow_clk_hz);
	if(is_shifted == 1'b1)
		return MAIN_HZ / slow_clk_hz / 2 - MAIN_HZ / slow_clk_hz / 4;
	else
		return 0;
endfunction


// generate clock
logic [HZ_BITS - 1 : 0] clk_ctr;

logic clk;
assign out_clk = clk;


always_ff@(posedge in_clk, posedge in_reset) begin
	if(in_reset == 1'b1) begin
		clk <= in_clk_init;
		clk_ctr <= get_clk_shift(in_clk_shift, in_clk_hz);
	end

	else begin
		if(clk_ctr >= MAIN_HZ / in_clk_hz / 2 - 1) begin
			clk <= ~clk;
			clk_ctr <= 1'b0;
		end else begin
			clk_ctr <= clk_ctr + 1'b1;
    end
	end
end


endmodule
