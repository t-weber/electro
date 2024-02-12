/**
 * serial controller: serialises parallel data
 * @author Tobias Weber
 * @date 22-dec-2023
 * @license see 'LICENSE' file
 */

module serial
#(
	// clock frequencies
	parameter MAIN_CLK_HZ   = 50_000_000,
	parameter SERIAL_CLK_HZ = 10_000,

	// inactive signals
	parameter SERIAL_CLK_INACTIVE  = 1,
	parameter SERIAL_DATA_INACTIVE = 1,

	// word length
	parameter BITS         = 8,
	parameter LOWBIT_FIRST = 1
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// serial output data
	output wire out_clk,
	output wire out_ready,
	output wire out_serial,
	output wire out_next_word,

	// parallel input data
	input wire [BITS-1 : 0] in_parallel,
	input wire in_enable
);


// serial states and next-state logic
typedef enum bit [1 : 0] { Ready, Transmit } t_serial_state;
t_serial_state serial_state      = Ready;
t_serial_state next_serial_state = Ready;

// input register
reg [BITS-1 : 0] parallel_data, next_parallel_data;

// serial clock
reg serial_clk = 1;

// bit counter
reg [$clog2(BITS) : 0] bit_ctr = 0;
reg [$clog2(BITS) : 0] next_bit_ctr;

// output registers
reg serial = SERIAL_DATA_INACTIVE;
reg next_word = 0;
assign out_serial = serial;
assign out_next_word = next_word;


// generate serial clock
localparam CLK_CTR_MAX = MAIN_CLK_HZ / SERIAL_CLK_HZ / 2 - 1;
int clk_ctr = 0;

always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1) begin
		clk_ctr <= 0;
		serial_clk <= 1;
	end

	// clock
	else if(in_clk == 1) begin
		if(clk_ctr == CLK_CTR_MAX) begin
			clk_ctr <= 0;
			serial_clk <= !serial_clk;
		end
		else begin
			clk_ctr <= clk_ctr + 1;
		end
	end
end

// output serial clock
generate
	if(SERIAL_CLK_INACTIVE == 1) begin
		// inactive '1' and trigger on falling edge
		assign out_clk = serial_state == Transmit ? serial_clk : 1;
	end else begin
		// inactive '0' and trigger on rising edge
		assign out_clk = serial_state == Transmit ? ~serial_clk : 0;
	end
endgenerate

assign out_ready = serial_state == Ready;


// state flip-flops for serial clock
always_ff@(posedge serial_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1) begin
		// state register
		serial_state <= Ready;

		// counter register
		bit_ctr <= 0;
	end

	// clock
	else if(serial_clk == 1) begin
		// state register
		serial_state <= next_serial_state;

		// counter register
		bit_ctr <= next_bit_ctr;
	end
end


// state flip-flops for main clock
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1) begin
		// parallel data register
		parallel_data <= 0;
	end

	// clock
	else if(in_clk == 1) begin
		// parallel data register
		parallel_data <= next_parallel_data;
	end
end


// buffer input parallel data
always@(in_enable, in_parallel, parallel_data) begin
	next_parallel_data <= parallel_data;

	if(in_enable == 1) begin
		next_parallel_data <= in_parallel;
	end
end


// state combinatorics
always_comb begin
	//defaults
	next_serial_state = serial_state;
	next_bit_ctr = bit_ctr;

	next_word = 0;
	serial = SERIAL_DATA_INACTIVE;

	// state machine
	case(serial_state)
		// wait for enable signal
		Ready: begin
			next_bit_ctr = 0;
			if(in_enable == 1) begin
				next_serial_state = Transmit;
			end
		end

		// serialise parallel data
		Transmit: begin
			// output current bit
			if(LOWBIT_FIRST == 1) begin
				serial = parallel_data[bit_ctr];
			end else begin
				serial = parallel_data[BITS - bit_ctr - 1];
			end

			// end of word?
			if(bit_ctr == BITS - 1) begin
				next_word = 1;
				next_bit_ctr = 0;
			end else begin
				next_bit_ctr = bit_ctr + 1;
			end

			// enable signal not active any more?
			if(in_enable == 0) begin
				next_serial_state = Ready;
			end
		end

		default: begin
			next_serial_state = Ready;
		end
	endcase
end


endmodule
