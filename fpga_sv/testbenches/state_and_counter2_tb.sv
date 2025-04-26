/**
 * test for states with counters
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 26-apr-2025
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o state_and_counter2_tb state_and_counter2_tb.sv
 * ./state_and_counter2_tb
 * gtkwave state_and_counter2_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


 `timescale 1ns / 100ps
`default_nettype /*wire*/ none  // no implicit declarations


module state_and_counter2_tb;

localparam ITERS = 100;
localparam BITS  = 5;


// clock
logic theclk = 1'b1;


// states
typedef enum
{
	Start, Count, Finished
} t_state;

t_state state = Start, state_next = Start;
logic[BITS - 1 : 0] ctr = BITS'(1'b1), ctr_next = BITS'(1'b1);
logic[BITS - 1 : 0] CTR_VAL1 = BITS'(10);
logic[BITS - 1 : 0] CTR_VAL2 = BITS'(25);


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
	ctr_next = (state == Count) ? ctr + 1'b1 : ctr;

	//case({ state, ctr }) inside
	casez({ state, ctr })
		{ Start, {BITS{1'b?}} }: begin
			state_next = Count;
			ctr_next = BITS'(1'b0);
		end

		{ Count, CTR_VAL1 }: begin
			$display("t = %3t: At CTR_VAL1 = %d.", $time, CTR_VAL1);
		end

		{ Count, CTR_VAL2 }: begin
			$display("t = %3t: At CTR_VAL2 = %d.", $time, CTR_VAL2);
		end

		{ Count, {BITS{1'b1}} }: begin
			state_next = Finished;
			ctr_next = BITS'(1'b0);
		end

		{ Finished, {BITS{1'b?}} }: begin
			$display("t = %3t: Finished.", $time);
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
	$dumpfile("state_and_counter2_tb.vcd");
	$dumpvars(0, state_and_counter2_tb);

	for(iter = 0; iter < ITERS; ++iter) begin
		#1;
		theclk = !theclk;
	end

	$dumpflush();
end
//---------------------------------------------------------------------------


endmodule
