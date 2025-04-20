/**
 * test for states with counters
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 20-apr-2025
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o state_and_counter_tb state_and_counter_tb.sv
 * ./state_and_counter_tb
 * gtkwave state_and_counter_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


 `timescale 1ns / 100ps
`default_nettype /*wire*/ none  // no implicit declarations


module state_and_counter_tb;

localparam ITERS = 24;
localparam BITS  = 4;


// clock
logic theclk = 1'b1;


// states
typedef enum
{
	Start, Count, Finished
} t_state;

t_state state = Start, state_next = Start;
logic[BITS - 1 : 0] ctr = BITS'(1'b1), ctr_next = BITS'(1'b1);


//---------------------------------------------------------------------------
//-- state machine
//---------------------------------------------------------------------------
always_ff@(posedge theclk) begin
	state <= state_next;
	ctr <= ctr_next;
end


always_comb begin
	// defaults
	state_next = state;
	ctr_next = ctr;

	//unique0 case({ state, ctr }) inside
	unique0 casez({ state, ctr })
		{ Start, {BITS{1'b?}} }: begin
			state_next = Count;
			ctr_next = BITS'(1'b0);
		end

		//{ Count, [4'b0000 : 4'b0111] }: begin
		{ Count, BITS'(4'b0???) }: begin
			ctr_next = ctr + 1'b1;
		end

		//{ Count, [4'b1000 : 4'b1111] }: begin
		{ Count, BITS'(4'b1???) }: begin
			state_next = Finished;
		end

		{ Finished, {BITS{1'b?}} }: begin
		end
	endcase
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
//-- debug output
//---------------------------------------------------------------------------
always@(posedge theclk) begin
	$display("t = %3t", $time,
		", clk = %b", theclk,
		", state = %9s", state.name(),
		", ctr = %d", ctr);
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// run simulation
//---------------------------------------------------------------------------
integer iter;

initial begin
	$dumpfile("state_and_counter_tb.vcd");
	$dumpvars(0, state_and_counter_tb);

	for(iter = 0; iter < ITERS; ++iter) begin
		#1;
		theclk = !theclk;
	end

	$dumpflush();
end
//---------------------------------------------------------------------------


endmodule
