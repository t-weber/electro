/**
 * testing signal delays
 * @author Tobias Weber
 * @date 20-apr-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o delay_tb delay_tb.sv
 */

`timescale 1ms / 1us

module delay_tb(
	output reg out_direct,
	output wire out_viareg,
	output wire out_vianext
);

localparam CTR_MAX = 3;
int ctr = 0;

localparam MAX_CLK_ITER = 16;
int clk_iter = 0;

// clock and reset
reg clk = 1'b1, rst = 1'b0;

//reg direct = 1'b0;
reg outreg = 1'b0;
reg viareg = 1'b0;
reg outreg2 = 1'b0, next_outreg2 = 1'b0;

//assign out_direct = direct;
assign out_viareg = viareg;
assign out_vianext = outreg2;


// states and next-state logic
typedef enum integer { Start, One, Zero, Finish } t_state;
t_state state = Start, next_state = Start;


// state flip-flop
always_ff@(posedge clk, posedge rst) begin
	// reset
	if(rst == 1'b1) begin
		state <= Start;
		outreg2 <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;
		outreg2 <= next_outreg2;
	end
end


// state combinatorics
always_comb begin
	//defaults
	next_state = state;
	next_outreg2 = outreg2;
	out_direct = 1'b0;

	// state machine
	case(state)
		Start: begin
			ctr = 1'b0;
			next_state = One;
		end

		One: begin
			next_state = Zero;
			next_outreg2 = 1'b1;
			out_direct = 1'b1;
		end

		Zero: begin
			ctr = ctr + 1'b1;
			if(ctr == CTR_MAX)
				next_state = Finish;
			else
				next_state = One;

			next_outreg2 = 1'b0;
		end

		Finish: begin
		end

		default: begin
			next_state = Start;
		end
	endcase
end


// output register
always_ff@(posedge clk, posedge rst) begin
	// reset
	if(rst == 1'b1) begin
		viareg <= 1'b0;
	end

	// clock
	else begin
		// default
		viareg <= 1'b0;

		case(next_state)
			One: begin
				viareg <= 1'b1;
			end
		endcase
	end
end


// run simulation
initial begin
	rst <= 1;
	clk <= 0; #1;
	clk <= 1; #1;
	clk <= 0; #1;
	rst <= 0;

	for(clk_iter = 0; clk_iter < MAX_CLK_ITER; ++clk_iter) begin
		clk <= !clk; #1;
	end
end


// print status
always@(clk) begin
	$display("clk_iter = %0d: t=%0t, clk=%b, rst=%b, state=%s, out_direct=%b, out_viareg=%b, out_vianext=%b",
		clk_iter, $time, clk, rst, state.name(), out_direct, out_viareg, out_vianext);
end

endmodule
