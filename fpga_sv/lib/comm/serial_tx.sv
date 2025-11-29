/**
 * serial controller for 3-wire interface, only transmission
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 17-aug-2024
 * @license see 'LICENSE' file
 */

module serial_tx
#(
	// clock frequencies
	parameter longint MAIN_CLK_HZ   = 50_000_000,
	parameter longint SERIAL_CLK_HZ = 10_000,

	// inactive signals
	parameter bit SERIAL_CLK_INACTIVE     = 1'b1,
	parameter bit SERIAL_DATA_INACTIVE    = 1'b1,
	parameter bit KEEP_SERIAL_CLK_RUNNING = 1'b0,

	// signal triggers
	parameter bit FALLING_EDGE = 1'b1,

	// word length
	parameter byte BITS        = 8,
	parameter bit LOWBIT_FIRST = 1'b1
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// serial clock
	output wire out_clk,
	output wire out_clk_raw,

	// not currently transmitting
	output wire out_ready,

	// enable transmission
	input wire in_enable,

	// request next word (one cycle before current word is finished)
	output wire out_next_word,

	// current word finished
	output wire out_word_finished,

	// parallel input data
	input wire [BITS - 1 : 0] in_parallel,

	// serial output data
	output wire out_serial
);


// ----------------------------------------------------------------------------
// serial states for transmission and next-state logic
// ----------------------------------------------------------------------------
typedef enum bit [0 : 0] { Ready, Transmit } t_serial_state;

t_serial_state serial_state = Ready;
t_serial_state next_serial_state = Ready;

assign out_ready = (serial_state == Ready);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// bit counters
// ----------------------------------------------------------------------------
logic [$clog2(BITS) : 0] bit_ctr = 1'b0, next_bit_ctr = 1'b0;

// bit counter with correct ordering
wire [$clog2(BITS) : 0] actual_bit_ctr;

generate
	if(LOWBIT_FIRST == 1'b1) begin
		assign actual_bit_ctr = bit_ctr;
	end else begin
		assign actual_bit_ctr =
			$size(bit_ctr)'(BITS - bit_ctr - 1'b1);
	end
endgenerate
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// generate serial clock
// ----------------------------------------------------------------------------
logic serial_clk;

clkgen #(
		.MAIN_CLK_HZ(MAIN_CLK_HZ), .CLK_HZ(SERIAL_CLK_HZ),
		.CLK_INIT(1'b1)
	)
	serial_clk_mod
	(
		.in_clk(in_clk), .in_rst(in_rst),
		.out_clk(serial_clk)
	);


assign out_clk_raw = serial_clk;


// generate serial clock output
generate
if(KEEP_SERIAL_CLK_RUNNING == 1'b1) begin
	if(SERIAL_CLK_INACTIVE == 1'b1) begin
		// inactive '1' and trigger on rising edge
		assign out_clk = serial_clk;
	end else begin
		// inactive '0' and trigger on falling edge
		assign out_clk = ~serial_clk;
	end
end else begin
	// stop serial clock when not transmitting
	if(SERIAL_CLK_INACTIVE == 1'b1) begin
		// inactive '1' and trigger on rising edge
		assign out_clk =
			serial_state == Transmit || in_enable == 1'b1
			? serial_clk
			: 1'b1;
	end else begin
		// inactive '0' and trigger on falling edge
		assign out_clk =
			serial_state == Transmit || in_enable == 1'b1
			? ~serial_clk
			: 1'b0;
	end
end
endgenerate
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// output parallel data to register
// ----------------------------------------------------------------------------
logic [BITS - 1 : 0] parallel = 1'b0, next_parallel = 1'b0;

// serial output
assign out_serial = serial_state == Transmit
	? parallel[actual_bit_ctr]
	: SERIAL_DATA_INACTIVE;

logic request_word = 1'b0, next_request_word = 1'b0;
assign out_word_finished = request_word;
assign out_next_word = next_request_word;


generate
if(FALLING_EDGE == 1'b1) begin
	always_ff@(negedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1) begin
			// state register
			serial_state <= Ready;

			// data
			parallel <= 1'b0;

			// counter register
			bit_ctr <= 1'b0;
			request_word <= 1'b0;
		end else begin
			// state register
			serial_state <= next_serial_state;

			// data
			parallel <= next_parallel;

			// counter register
			bit_ctr <= next_bit_ctr;
			request_word <= next_request_word;
		end
	end
end else begin
	always_ff@(posedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1) begin
			// state register
			serial_state <= Ready;

			// data
			parallel <= 1'b0;

			// counter register
			bit_ctr <= 1'b0;
			request_word <= 1'b0;
		end else begin
			// state register
			serial_state <= next_serial_state;

			// data
			parallel <= next_parallel;

			// counter register
			bit_ctr <= next_bit_ctr;
			request_word <= next_request_word;
		end
	end
end
endgenerate


always_comb begin
	// defaults
	next_serial_state = serial_state;
	next_parallel = parallel;
	next_bit_ctr = bit_ctr;
	next_request_word = 1'b0;

	if(in_enable == 1'b1)
		next_parallel = in_parallel;

`ifdef __IN_SIMULATION__
	$display("** serial: %d, bit %d, ",
		serial_state/*.name()*/, actual_bit_ctr,
		"%x. **", parallel);
`endif

	unique case(serial_state)
		// wait for enable signal
		Ready: begin
			next_bit_ctr = 1'b0;
			if(in_enable == 1'b1)
				next_serial_state = Transmit;
		end

		// serialise parallel data
		Transmit: begin
			// end of word?
			if(bit_ctr == BITS - 1'b1) begin
				next_request_word = 1'b1;
				next_bit_ctr = 1'b0;
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
			end

			// enable signal not active any more?
			if(in_enable == 1'b0)
				next_serial_state = Ready;
		end

		default: begin
			next_serial_state = Ready;
		end
	endcase
end
// ----------------------------------------------------------------------------


endmodule
