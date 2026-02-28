/**
 * timed sequence of tones
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 24-may-2025, 19-feb-2026
 * @license see 'LICENSE' file
 */

module tones
#(
	// clock
	parameter MAIN_HZ   = 50_000_000,
	parameter FREQ_BITS = 16
)
(
	// main clock and reset
	input wire in_clk, in_reset,
	input wire in_enable,

	output wire [FREQ_BITS - 1 : 0] out_freq,
	output wire [7 : 0] out_cycle,
	output wire out_finished
);


// states
typedef enum
{
	Reset, Idle,
	SeqData, SeqDuration, SeqDelay, SeqNext
} t_state;

t_state state, next_state;


/**
 * tone sequence (see: tools/gentones/gentones.cpp)
 *   melody: https://en.wikipedia.org/wiki/Symphony_No._9_(Beethoven)#IV._Finale
 *   tuning: https://en.wikipedia.org/wiki/Equal_temperament
 */
localparam int DUR_BITS = $clog2(MAIN_HZ) - 1;
localparam int NUM_TONES = 57;
localparam [DUR_BITS - 1 : 0] def_delay = MAIN_HZ / 20;

logic [0 : NUM_TONES - 1][FREQ_BITS - 1 : 0] frequencies;
assign frequencies = {
	// sequence 1
	FREQ_BITS'(522), FREQ_BITS'(553), FREQ_BITS'(621), 
	// sequence 2
	FREQ_BITS'(621), FREQ_BITS'(553), FREQ_BITS'(522), FREQ_BITS'(465), 
	// sequence 3
	FREQ_BITS'(414), FREQ_BITS'(465), FREQ_BITS'(522), 
	// sequence 4
	FREQ_BITS'(522), FREQ_BITS'(465), FREQ_BITS'(465), 
	// sequence 5
	FREQ_BITS'(522), FREQ_BITS'(553), FREQ_BITS'(621), 
	// sequence 6
	FREQ_BITS'(621), FREQ_BITS'(553), FREQ_BITS'(522), FREQ_BITS'(465), 
	// sequence 7
	FREQ_BITS'(414), FREQ_BITS'(465), FREQ_BITS'(522), 
	// sequence 8
	FREQ_BITS'(465), FREQ_BITS'(414), FREQ_BITS'(414), 
	// sequence 9
	FREQ_BITS'(465), FREQ_BITS'(522), FREQ_BITS'(414), 
	// sequence 10
	FREQ_BITS'(465), FREQ_BITS'(522), FREQ_BITS'(553), FREQ_BITS'(522), FREQ_BITS'(414), 
	// sequence 11
	FREQ_BITS'(465), FREQ_BITS'(522), FREQ_BITS'(553), FREQ_BITS'(522), FREQ_BITS'(465), 
	// sequence 12
	FREQ_BITS'(414), FREQ_BITS'(465), FREQ_BITS'(310), FREQ_BITS'(522), 
	// sequence 13
	FREQ_BITS'(522), FREQ_BITS'(522), FREQ_BITS'(553), FREQ_BITS'(621), 
	// sequence 14
	FREQ_BITS'(621), FREQ_BITS'(553), FREQ_BITS'(522), FREQ_BITS'(465), 
	// sequence 15
	FREQ_BITS'(414), FREQ_BITS'(465), FREQ_BITS'(522), 
	// sequence 16
	FREQ_BITS'(465), FREQ_BITS'(414), FREQ_BITS'(414)
};

logic [0 : NUM_TONES - 1][DUR_BITS - 1 : 0] durations;
assign durations = {
	// sequence 1
	DUR_BITS'(MAIN_HZ / 1000 * 665), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 2
	DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 3
	DUR_BITS'(MAIN_HZ / 1000 * 665), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 4
	DUR_BITS'(MAIN_HZ / 1000 * 499), DUR_BITS'(MAIN_HZ / 1000 * 166), DUR_BITS'(MAIN_HZ / 1000 * 665), 
	// sequence 5
	DUR_BITS'(MAIN_HZ / 1000 * 665), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 6
	DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 7
	DUR_BITS'(MAIN_HZ / 1000 * 665), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 8
	DUR_BITS'(MAIN_HZ / 1000 * 499), DUR_BITS'(MAIN_HZ / 1000 * 166), DUR_BITS'(MAIN_HZ / 1000 * 665), 
	// sequence 9
	DUR_BITS'(MAIN_HZ / 1000 * 665), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 10
	DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 166), DUR_BITS'(MAIN_HZ / 1000 * 166), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 11
	DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 166), DUR_BITS'(MAIN_HZ / 1000 * 166), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 12
	DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 13
	DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 14
	DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 15
	DUR_BITS'(MAIN_HZ / 1000 * 665), DUR_BITS'(MAIN_HZ / 1000 * 333), DUR_BITS'(MAIN_HZ / 1000 * 333), 
	// sequence 16
	DUR_BITS'(MAIN_HZ / 1000 * 499), DUR_BITS'(MAIN_HZ / 1000 * 166), DUR_BITS'(MAIN_HZ / 1000 * 665)
};

logic [0 : NUM_TONES - 1][DUR_BITS - 1 : 0] delays;
assign delays = {
	// sequence 1
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 2
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 3
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 4
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 5
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 6
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 7
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 8
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 9
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 10
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 11
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 12
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 13
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 14
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 15
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), 
	// sequence 16
	DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20), DUR_BITS'(MAIN_HZ / 20)
};


// sequence
logic [FREQ_BITS - 1 : 0] seq_freq, next_seq_freq;
logic [$clog2(NUM_TONES) - 1 : 0] seq_cycle, next_seq_cycle;
int seq_duration, next_seq_duration;
int seq_delay, next_seq_delay;

int wait_ctr, wait_ctr_max;  // counter for busy wait


// data output
assign out_freq = seq_freq;
assign out_cycle = seq_cycle;
assign out_finished = (state == Idle);


/**
 * state flip-flops
 */
always_ff@(posedge in_clk, posedge in_reset) begin
	if(in_reset == 1'b1) begin
		// state register
		state <= Reset;

		// sequence data, duration, and delay
		seq_freq <= 1'b0;
		seq_duration <= 1'b0;
		seq_delay <= 1'b0;

		// command counter
		seq_cycle <= 1'b0;

		// timer register
		wait_ctr <= 1'b0;
	end
	else begin
		// state register
		state <= next_state;

		// sequence data
		seq_freq <= next_seq_freq;
		seq_duration <= next_seq_duration;
		seq_delay <= next_seq_delay;

		// command counter
		seq_cycle <= next_seq_cycle;

		// timer register
		if (wait_ctr == wait_ctr_max) begin
			// reset timer counter
			wait_ctr <= 1'b0;
		end else begin
			// next timer counter
			wait_ctr <= wait_ctr + 1'b1;
		end
	end
end


/**
 * state combinatorics
 */
always_comb begin
	// defaults
	next_state = state;
	next_seq_freq = seq_freq;
	next_seq_duration = seq_duration;
	next_seq_delay = seq_delay;
	next_seq_cycle = seq_cycle;
	wait_ctr_max = 1'b0;

	// fsm
	unique case(state)
		// reset
		Reset: begin
			if(in_enable == 1'b1)
				next_state = SeqData;
		end

		// sequence finished
		Idle: begin
		end

		// --------------------------------------------------------------------------
		// sequence
		// --------------------------------------------------------------------------
		SeqData: begin
			// write the rest of the value bits
				next_seq_freq = frequencies[seq_cycle];
				next_seq_duration = durations[seq_cycle];
				next_seq_delay = delays[seq_cycle];
				next_state = SeqDuration;
		end

		SeqDuration: begin
			wait_ctr_max = seq_duration;
			if(wait_ctr == wait_ctr_max)
				next_state = SeqDelay;
		end

		SeqDelay: begin
			next_seq_freq = 1'b0;
			wait_ctr_max = seq_delay;
			if(wait_ctr == wait_ctr_max)
				next_state = SeqNext;
		end

		SeqNext: begin
			if(seq_cycle == NUM_TONES - 1'b1) begin
				// at end of sequence
			  next_state = Idle;
			  next_seq_cycle = 1'b0;
			end else begin
			  // next sequence item
			  next_seq_cycle = seq_cycle + 1'b1;
			  next_state = SeqData;
			end
		end
		// --------------------------------------------------------------------------

		default: begin
			next_state = Reset;
		end
	endcase
end


endmodule
