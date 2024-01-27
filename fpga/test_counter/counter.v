//
// simple counter
// @author Tobias Weber <tobias.weber@tum.de>
// @date 16-April-2023
// @license see 'LICENSE' file
//


module counter
	#(parameter num_ctrbits = 16)
	(
		input wire in_clk,
		input wire in_rst,
		output wire [num_ctrbits-1 : 0] out_ctr
	);


reg [num_ctrbits-1 : 0] ctr, next_ctr;
assign out_ctr = ctr;


always@(posedge in_clk, posedge in_rst) begin

	if(in_rst) begin
		ctr <= 0;
	end
	else if(in_clk)	begin
		ctr <= next_ctr;
	end

end


always@(ctr) begin
	next_ctr <= ctr + 1;
end


endmodule
