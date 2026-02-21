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
typedef struct packed
{
	logic [FREQ_BITS - 1 : 0] freq;
	int duration;  // time to keep frequency
	int delay;     // time to wait before next frequency
} t_seq;


/**
 * tone sequence (see: tools/gentones/gentones.cpp)
 *   melody: https://en.wikipedia.org/wiki/Symphony_No._9_(Beethoven)#IV._Finale
 *   tuning: https://en.wikipedia.org/wiki/Equal_temperament
 */
localparam int NUM_TONES = 57;
localparam int def_delay = int'(MAIN_HZ / 20);

t_seq [ NUM_TONES ] seq_arr = {
	// sequence 1
	{ 16'd522, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 0
	{ 16'd553, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 1
	{ 16'd621, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 2
	
	// sequence 2
	{ 16'd621, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 3
	{ 16'd553, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 4
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 5
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 6
	
	// sequence 3
	{ 16'd414, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 7
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 8
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 9
	
	// sequence 4
	{ 16'd522, int'(MAIN_HZ / 1000 * 499), def_delay },  // tone 10
	{ 16'd465, int'(MAIN_HZ / 1000 * 166), def_delay },  // tone 11
	{ 16'd465, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 12
	
	// sequence 5
	{ 16'd522, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 13
	{ 16'd553, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 14
	{ 16'd621, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 15
	
	// sequence 6
	{ 16'd621, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 16
	{ 16'd553, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 17
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 18
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 19
	
	// sequence 7
	{ 16'd414, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 20
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 21
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 22
	
	// sequence 8
	{ 16'd465, int'(MAIN_HZ / 1000 * 499), def_delay },  // tone 23
	{ 16'd414, int'(MAIN_HZ / 1000 * 166), def_delay },  // tone 24
	{ 16'd414, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 25
	
	// sequence 9
	{ 16'd465, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 26
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 27
	{ 16'd414, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 28
	
	// sequence 10
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 29
	{ 16'd522, int'(MAIN_HZ / 1000 * 166), def_delay },  // tone 30
	{ 16'd553, int'(MAIN_HZ / 1000 * 166), def_delay },  // tone 31
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 32
	{ 16'd414, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 33
	
	// sequence 11
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 34
	{ 16'd522, int'(MAIN_HZ / 1000 * 166), def_delay },  // tone 35
	{ 16'd553, int'(MAIN_HZ / 1000 * 166), def_delay },  // tone 36
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 37
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 38
	
	// sequence 12
	{ 16'd414, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 39
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 40
	{ 16'd310, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 41
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 42
	
	// sequence 13
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 43
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 44
	{ 16'd553, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 45
	{ 16'd621, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 46
	
	// sequence 14
	{ 16'd621, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 47
	{ 16'd553, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 48
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 49
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 50
	
	// sequence 15
	{ 16'd414, int'(MAIN_HZ / 1000 * 665), def_delay },  // tone 51
	{ 16'd465, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 52
	{ 16'd522, int'(MAIN_HZ / 1000 * 333), def_delay },  // tone 53
	
	// sequence 16
	{ 16'd465, int'(MAIN_HZ / 1000 * 499), def_delay },  // tone 54
	{ 16'd414, int'(MAIN_HZ / 1000 * 166), def_delay },  // tone 55
	{ 16'd414, int'(MAIN_HZ / 1000 * 665), def_delay }   // tone 56
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
