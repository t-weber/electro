/**
 * test for stack module
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-aug-2024
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -D__IN_SIMULATION__ -o stack_tb stack_tb.sv ../mem/stack.sv
 * ./stack_tb
 * gtkwave stack_tb.vcd --rcvar "do_initial_zoom_fit yes"
 */


 `timescale 1ns / 100ps
`default_nettype /*wire*/ none  // no implicit declarations


module stack_tb;

localparam ITERS = 32;

// address and data widths
localparam ADDR_WIDTH = 8;
localparam DATA_WIDTH = 8;


logic theclk = 1'b1, reset = 1'b1;

// states
typedef enum
{
	Start, WaitReady,
	PushTest1, PushTest2,
	PopTest,
	Finished
} t_state;

t_state state = Start, state_next = Start;
t_state state_after_ready = Start, state_after_ready_next = Start;

logic [1 : 0] cmd;
logic [DATA_WIDTH - 1 : 0] data, data_next, top;
logic ready;


//---------------------------------------------------------------------------
//-- state machine
//---------------------------------------------------------------------------
always_ff@(posedge theclk) begin
	state <= state_next;
	state_after_ready <= state_after_ready_next;
	data <= data_next;
end


//
// test input sequence
//
always_comb begin
	// defaults
	state_next = state;
	state_after_ready_next = state_after_ready;
	data_next = data;

	reset = 1'b0;
	cmd = 2'b00;

	case(state)
		Start: begin
			reset = 1'b1;
			state_after_ready_next = PushTest1;
			state_next = WaitReady;
		end

		WaitReady: begin
			if(ready == 1'b1)
				state_next = state_after_ready;
		end

		PushTest1: begin
			cmd = 2'b01;
			data_next = 8'h12;
			state_next = WaitReady;
			state_after_ready_next = PushTest2;
		end

		PushTest2: begin
			cmd = 2'b01;
			data_next = 8'h98;
			state_next = WaitReady;
			state_after_ready_next = PopTest;
		end

		PopTest: begin
			cmd = 2'b10;
			state_next = WaitReady;
			state_after_ready_next = Finished;
		end

		Finished: begin
			$display("==== FINISHED ====");
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
		", data = 0x%h", data, " = 0b%b", data,
		", stack_top = 0x%h", top);
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
//-- stack module
//---------------------------------------------------------------------------
stack #(.ADDR_BITS(ADDR_WIDTH), .WORD_BITS(DATA_WIDTH))
stack_mod(
	.in_clk(theclk), .in_rst(reset),
	.in_cmd(cmd), .in_data(data),
	.out_top(top), .out_ready(ready));
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// run simulation
//---------------------------------------------------------------------------
integer iter;

initial begin
	$dumpfile("stack_tb.vcd");
	$dumpvars(0, stack_tb);

	for(iter = 0; iter < ITERS; ++iter) begin
		#1;
		theclk = !theclk;
	end

	$dumpflush();
end
//---------------------------------------------------------------------------

endmodule
