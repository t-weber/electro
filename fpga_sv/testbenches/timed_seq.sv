/**
 * timed sequence
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 25-may-2025
 * @license see 'LICENSE' file
 */


module timed_seq
#(
	// main clock frequency
	parameter MAIN_HZ = 50_000_000,

	// dat word length
	parameter DATA_BITS = 8
)
(
	// clock and reset
	input wire in_clk, in_rst,
	input wire in_enable,

	output wire [DATA_BITS - 1 : 0] out_data
);



typedef enum {
	Reset, Idle,
	SeqData, SeqDuration, SeqNext
} t_state;

t_state state = Reset, next_state = Reset;


// maximum possible delay
localparam const_wait_max = MAIN_HZ;  // 1 s
localparam WAIT_BITS = $clog2(const_wait_max) + 1'b1;


// busy wait counters
logic [WAIT_BITS - 1 : 0] wait_counter = 1'b0, wait_counter_max = 1'b0;
logic [WAIT_BITS - 1 : 0] duration = 1'b0, next_duration = 1'b0;


// data struct
typedef struct packed
{
	logic [DATA_BITS - 1 : 0] data;
	logic [WAIT_BITS - 1 : 0] duration;
} t_seq;

// sequence array
localparam num_data = 2;
t_seq [0 : num_data - 1] seq_arr;
assign seq_arr =
{
	{ DATA_BITS'(8'b10101010), WAIT_BITS'(MAIN_HZ/1_000*500) },
	{ DATA_BITS'(8'b01010101), WAIT_BITS'(MAIN_HZ/1_000*500) }
};

/*initial begin
	seq_arr[0] = { DATA_BITS'(8'b10101010), WAIT_BITS'(MAIN_HZ/1_000*500) };
end*/


// sequence cycle counter
logic [$clog2(num_data) : 0] cycle = 1'b0, next_cycle = 1'b0;


// output
logic [DATA_BITS - 1 : 0] bus_data = 1'b0, next_bus_data = 1'b0;
assign out_data = bus_data;



/**
 * state flip-flops
 */
always_ff@(posedge in_clk) begin
	// reset
	if(in_rst == 1'b1) begin
		// state register
		state <= Reset;

		// data to put on bus
		bus_data <= 1'b0;
		duration <= 1'b0;

		// timer register
		wait_counter <= 1'b0;

		// counter register
		cycle <= 1'b0;
	end

	// clock
	else begin
		// state register
		state <= next_state;

		// data to put on bus
		bus_data <= next_bus_data;
		duration <= next_duration;

		// timer register
		if(wait_counter == wait_counter_max) begin
			// reset timer counter
			wait_counter <= 1'b0;
		end else begin
			// next timer counter
			wait_counter <= wait_counter + 1'b1;
		end

		// counter register
		cycle <= next_cycle;
	end
end



/**
 * state combinatorics
 */
always_comb begin
	// defaults
	next_state = state;
	next_bus_data = bus_data;
	next_duration = duration;
	next_cycle = cycle;
	wait_counter_max = 1'b0;


	unique case(state)
		// --------------------------------------------------------------------
		// reset and idle state
		// --------------------------------------------------------------------
		Reset: begin
			if(in_enable == 1'b1)
				next_state = SeqData;
		end

		Idle: begin
		end
		// --------------------------------------------------------------------


		// --------------------------------------------------------------------
		// sequence
		// --------------------------------------------------------------------
		SeqData: begin
			// transmit data
			next_bus_data = seq_arr[cycle].data;
			next_duration = seq_arr[cycle].duration;
			next_state = SeqDuration;
		end

		SeqDuration: begin
			// hold the data for the duration
			wait_counter_max = duration;
			if(wait_counter == wait_counter_max) begin
				// continue with sequence
				next_state = SeqNext;
			end
		end

		SeqNext: begin
			if(cycle + 1'b1 == num_data) begin
				// at end of sequence
				next_state = Idle;
				next_cycle = 1'b0;
			end else begin
				// next sequence item
				next_cycle = cycle + 1'b1;
				next_state = SeqData;
			end
		end
		// --------------------------------------------------------------------


		default: begin
			next_state = Reset;
		end

	endcase
end


endmodule
