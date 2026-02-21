/**
 * testing structs
 * @author Tobias Weber
 * @date 19-feb-2026
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o structs structs.sv
 */

`timescale 1ms / 1us

module structs();


typedef struct packed
{
	logic val;
	logic [1 : 0] vec;
	logic [1 : 0] vec2;
} t_str;


t_str [4] strs;

assign strs =
{
	{ 1'b0, 2'd0, 2'd3 },
	{ 1'b1, 2'd1, 2'd2 },
	{ 1'b0, 2'd2, 2'd1 },
	{ 1'b1, 2'd3, 2'd0 }
};

/*
assign strs[0] = { 1'b0, 2'd0, 2'd3 };
assign strs[1] = { 1'b1, 2'd1, 2'd2 };
assign strs[2] = { 1'b0, 2'd2, 2'd1 };
assign strs[3] = { 1'b1, 2'd3, 2'd0 };
*/


// run simulation
initial begin
	for(int i = 0; i < $size(strs); ++i) begin
		$display("%d: %b %d %d", i, strs[i].val, strs[i].vec, strs[i].vec2);
	end
end


endmodule
