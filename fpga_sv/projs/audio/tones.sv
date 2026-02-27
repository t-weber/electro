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


// tone date struct
localparam int DUR_BITS = $clog2(MAIN_HZ) - 1;

typedef struct packed
{
	logic [FREQ_BITS - 1 : 0] freq;
	logic [DUR_BITS - 1 : 0]  duration;  // time to keep frequency
	logic [DUR_BITS - 1 : 0]  delay;     // time to wait before next frequency
} t_seq;


/**
 * tone sequence (see: tools/gentones/gentones.cpp)
 *   melody: https://en.wikipedia.org/wiki/Symphony_No._9_(Beethoven)#IV._Finale
 *   tuning: https://en.wikipedia.org/wiki/Equal_temperament
 */
localparam int NUM_TONES = 57;
localparam [DUR_BITS - 1 : 0] def_delay = MAIN_HZ / 20;

t_seq seq_arr[0 : NUM_TONES - 1] = {
	// sequence 1
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 0
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 1
	{ FREQ_BITS'(621), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 2
	
	// sequence 2
	{ FREQ_BITS'(621), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 3
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 4
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 5
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 6
	
	// sequence 3
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 7
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 8
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 9
	
	// sequence 4
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 499), def_delay },  // tone 10
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 166), def_delay },  // tone 11
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 12
	
	// sequence 5
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 13
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 14
	{ FREQ_BITS'(621), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 15
	
	// sequence 6
	{ FREQ_BITS'(621), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 16
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 17
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 18
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 19
	
	// sequence 7
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 20
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 21
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 22
	
	// sequence 8
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 499), def_delay },  // tone 23
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 166), def_delay },  // tone 24
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 25
	
	// sequence 9
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 26
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 27
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 28
	
	// sequence 10
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 29
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 166), def_delay },  // tone 30
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 166), def_delay },  // tone 31
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 32
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 33
	
	// sequence 11
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 34
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 166), def_delay },  // tone 35
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 166), def_delay },  // tone 36
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 37
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 38
	
	// sequence 12
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 39
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 40
	{ FREQ_BITS'(310), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 41
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 42
	
	// sequence 13
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 43
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 44
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 45
	{ FREQ_BITS'(621), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 46
	
	// sequence 14
	{ FREQ_BITS'(621), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 47
	{ FREQ_BITS'(553), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 48
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 49
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 50
	
	// sequence 15
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay },  // tone 51
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 52
	{ FREQ_BITS'(522), DUR_BITS'(MAIN_HZ / 1000 * 333), def_delay },  // tone 53
	
	// sequence 16
	{ FREQ_BITS'(465), DUR_BITS'(MAIN_HZ / 1000 * 499), def_delay },  // tone 54
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 166), def_delay },  // tone 55
	{ FREQ_BITS'(414), DUR_BITS'(MAIN_HZ / 1000 * 665), def_delay }   // tone 56
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
				next_seq_freq = seq_arr[seq_cycle].freq;
				next_seq_duration = seq_arr[seq_cycle].duration;
				next_seq_delay = seq_arr[seq_cycle].delay;
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
