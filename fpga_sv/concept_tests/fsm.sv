/**
 * testing fsm implementation variants
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 7-dec-2025
 * @license see 'LICENSE' file
 *
 * iverilog -g2012 -o fsm fsm.sv
 * ./fsm
 * gtkwave fsm.vcd --rcvar "do_initial_zoom_fit yes"
 */


`timescale 1us / 100ns          // clock period: 2us
`default_nettype /*wire*/ none  // no implicit declarations


module fsm;


// clock
localparam int MAX_CLK_ITER = 25;
logic theclk = 1'b0;
always #1 theclk = ~theclk;

// reset
localparam int RESET_ITERS = 4;
logic therst = 1'b1;


// states
typedef enum
{
	Start, One, Two, Three, Finish
} t_state;


//---------------------------------------------------------------------------
//-- three-process state machine
//---------------------------------------------------------------------------
// state variable
t_state fsm3_state = Start, fsm3_state_next = Start;

// wait counter
localparam int WAIT_DELAY = 5;
logic[$clog2(WAIT_DELAY) : 0] fsm3_wait_ctr = 1'b0, fsm3_wait_ctr_max = 1'b0;

// "output"
logic fsm3_out;


//
// flip-flops
//
always_ff@(posedge theclk, posedge therst) begin
	if(therst) begin
		// reset
		fsm3_state <= Start;
		fsm3_wait_ctr <= 1'b0;
	end

	else begin
		// clock
		fsm3_state <= fsm3_state_next;

		if(fsm3_wait_ctr == fsm3_wait_ctr_max)
			fsm3_wait_ctr <= 1'b0;
		else
			fsm3_wait_ctr <= fsm3_wait_ctr + 1'b1;
	end
end


//
// combinational logic
//
always_comb begin
	// defaults
	fsm3_state_next = fsm3_state;
	fsm3_wait_ctr_max = 0;

	unique case(fsm3_state)
		Start: begin
			fsm3_wait_ctr_max = WAIT_DELAY;
			if(fsm3_wait_ctr == fsm3_wait_ctr_max)
				fsm3_state_next = One;
		end

		One: begin
			fsm3_state_next = Two;
		end

		Two: begin
			fsm3_state_next = Three;
		end

		Three: begin
			fsm3_state_next = Finish;
		end

		Finish: begin
		end
	endcase
end


//
// combinational output logic
//
always_comb begin
	// defaults
	fsm3_out = 1'b0;

	unique case(fsm3_state)
		One, Three: begin
			fsm3_out = 1'b1;
		end

		default: begin
		end
	endcase
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
//-- two-process state machine
//---------------------------------------------------------------------------
// state variable
t_state fsm2_state = Start, fsm2_state_next = Start;

// wait counter
logic[$clog2(WAIT_DELAY) : 0] fsm2_wait_ctr = 1'b0, fsm2_wait_ctr_max = 1'b0;

// "output"
logic fsm2_out;


//
// flip-flops
//
always_ff@(posedge theclk, posedge therst) begin
	if(therst) begin
		// reset
		fsm2_state <= Start;
		fsm2_wait_ctr <= 1'b0;
	end

	else begin
		// clock
		fsm2_state <= fsm2_state_next;

		if(fsm2_wait_ctr == fsm2_wait_ctr_max)
			fsm2_wait_ctr <= 1'b0;
		else
			fsm2_wait_ctr <= fsm2_wait_ctr + 1'b1;
	end
end


//
// combinational logic
//
always_comb begin
	// defaults
	fsm2_state_next = fsm2_state;
	fsm2_wait_ctr_max = 0;
	fsm2_out = 1'b0;

	unique case(fsm2_state)
		Start: begin
			fsm2_wait_ctr_max = WAIT_DELAY;
			if(fsm2_wait_ctr == fsm2_wait_ctr_max)
				fsm2_state_next = One;
		end

		One: begin
			fsm2_state_next = Two;
			fsm2_out = 1'b1;
		end

		Two: begin
			fsm2_state_next = Three;
		end

		Three: begin
			fsm2_state_next = Finish;
			fsm2_out = 1'b1;
		end

		Finish: begin
		end
	endcase
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
//-- one-process state machine
//---------------------------------------------------------------------------
// state variable
t_state fsm1_state = Start;

// wait counter
logic[$clog2(WAIT_DELAY) : 0] fsm1_wait_ctr = 1'b0;

// "output"
logic fsm1_out;


//
// flip-flops and combinational logic
//
always@(posedge theclk, posedge therst) begin
	//static t_state fsm1_state = Start;
	//static logic[$clog2(WAIT_DELAY) : 0] fsm1_wait_ctr = 1'b0;

	if(therst) begin  // reset
		fsm1_state <= Start;
		fsm1_wait_ctr <= 0;
		fsm1_out <= 1'b0;
	end

	else begin        // clock
		fsm1_out <= 1'b0;

		unique case(fsm1_state)
			Start: begin
				if(fsm1_wait_ctr == WAIT_DELAY) begin
					fsm1_state <= One;
					fsm1_wait_ctr <= 1'b0;
					fsm1_out <= 1'b1;
				end else begin
					fsm1_wait_ctr <= fsm1_wait_ctr + 1'b1;
				end
			end

			One: begin
				fsm1_state <= Two;
			end

			Two: begin
				fsm1_state <= Three;
				fsm1_out <= 1'b1;
			end

			Three: begin
				fsm1_state <= Finish;
			end

			Finish: begin
			end
		endcase
	end
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
//-- debug output
//---------------------------------------------------------------------------
always@(/*posedge*/ theclk) begin
	assert(fsm3_state == fsm2_state) else $error("Invalid state (2, 3).");
	assert(fsm1_state == fsm2_state) else $error("Invalid state (1, 2).");

	assert(fsm3_wait_ctr == fsm2_wait_ctr) else $error("Invalid counter (2, 3).");
	assert(fsm1_wait_ctr == fsm2_wait_ctr) else $error("Invalid counter (1, 2).");

	assert(fsm3_out == fsm2_out) else $error("Invalid output (2, 3).");
	assert(fsm1_out == fsm2_out) else $error("Invalid output (1, 2).");

	$display("t = %3t", $time, ", ",
		"therst = %b", therst, ", ",
		"clk = %b", theclk, ", ",
		"\nFSM3: state = %9s", fsm3_state.name(), ", ",
		"wait_ctr = %d", fsm3_wait_ctr, ", ",
		"output = %b", fsm3_out, ", ",
		"\nFSM2: state = %9s", fsm2_state.name(), ", ",
		"wait_ctr = %d", fsm2_wait_ctr, ", ",
		"output = %b", fsm2_out, ", ",
		"\nFSM1: state = %9s", fsm1_state.name(), ", ",
		"wait_ctr = %d", fsm1_wait_ctr, ", ",
		"output = %b", fsm1_out, "\n",
	);
end
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// run simulation
//---------------------------------------------------------------------------
initial begin
	$dumpfile("fsm.vcd");
	$dumpvars(0, fsm);

	therst = 1'b1;
	#(RESET_ITERS);
	therst = 1'b0;

	#(MAX_CLK_ITER);

	$dumpflush();
	$finish();
end
//---------------------------------------------------------------------------


endmodule
