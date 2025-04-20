/**
 * serial controller for 3-wire interface
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 22-dec-2023
 * @license see 'LICENSE' file
 */

module serial
#(
	// clock frequencies
	parameter MAIN_CLK_HZ   = 50_000_000,
	parameter SERIAL_CLK_HZ = 10_000,

	// inactive signals
	parameter SERIAL_CLK_INACTIVE     = 1'b1,
	parameter SERIAL_DATA_INACTIVE    = 1'b1,
	parameter KEEP_SERIAL_CLK_RUNNING = 1'b0,

	// signal triggers
	parameter FROM_FPGA_FALLING_EDGE  = 1'b1,
	parameter TO_FPGA_FALLING_EDGE    = 1'b1,

	// word length
	parameter BITS         = 8,
	parameter LOWBIT_FIRST = 1'b1
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

	// parallel input data (FPGA -> IC)
	input wire [BITS-1 : 0] in_parallel,

	// serial output data (FPGA -> IC)
	output wire out_serial,

	// serial input data (IC -> FPGA)
	input wire in_serial,

	// parallel output data (IC -> FPGA)
	output wire [BITS-1 : 0] out_parallel
);


// ----------------------------------------------------------------------------
// serial states and next-state logic
// ----------------------------------------------------------------------------
typedef enum bit [0 : 0] { Ready, Transmit } t_serial_state;

t_serial_state serial_state      = Ready;
t_serial_state next_serial_state = Ready;

assign out_ready = serial_state == Ready;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// bit counter
// ----------------------------------------------------------------------------
logic [$clog2(BITS) : 0] bit_ctr = 1'b0, next_bit_ctr = 1'b0;

// bit counter with correct ordering
wire [$clog2(BITS) : 0] actual_bit_ctr;

generate
	if(LOWBIT_FIRST == 1'b1) begin
		assign actual_bit_ctr = bit_ctr;
	end else begin
		assign actual_bit_ctr = $size(bit_ctr)'(BITS - bit_ctr - 1'b1);
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
	// keep serial clock running when not transmitting:
	// have to use the out_ready signal manually
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
		assign out_clk = serial_state == Transmit ? serial_clk : 1'b1;
	end else begin
		// inactive '0' and trigger on falling edge
		assign out_clk = serial_state == Transmit ? ~serial_clk : 1'b0;
	end
end
endgenerate
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// output parallel data to register (FPGA -> IC)
// ----------------------------------------------------------------------------
logic [BITS-1 : 0] parallel_fromfpga = 1'b0, next_parallel_fromfpga = 1'b0;

// serial output (FPGA -> IC)
assign out_serial = serial_state == Transmit
	? parallel_fromfpga[actual_bit_ctr]
	: SERIAL_DATA_INACTIVE;


logic request_word = 1'b0, next_request_word = 1'b0;
assign out_word_finished = request_word;
assign out_next_word = next_request_word;


generate
if(FROM_FPGA_FALLING_EDGE == 1'b1) begin
	always_ff@(negedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1)
			parallel_fromfpga <= 1'b0;
		else
			parallel_fromfpga <= next_parallel_fromfpga;
		end
end else begin
	always_ff@(posedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1)
			parallel_fromfpga <= 1'b0;
		else
			parallel_fromfpga <= next_parallel_fromfpga;
	end
end
endgenerate


always_comb begin
	next_parallel_fromfpga = parallel_fromfpga;

	if(in_enable == 1'b1)
		next_parallel_fromfpga = in_parallel;
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// buffer serial input (IC -> FPGA)
// ----------------------------------------------------------------------------
// parallel output buffer (IC -> FPGA)
logic [BITS-1 : 0] parallel_tofpga = 1'b0, next_parallel_tofpga = 1'b0;
assign out_parallel = parallel_tofpga;


generate
if(TO_FPGA_FALLING_EDGE == 1'b1) begin
	always_ff@(negedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1)
			parallel_tofpga <= 1'b0;
		else
			parallel_tofpga <= next_parallel_tofpga;
	end
end else begin
	always_ff@(posedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1)
			parallel_tofpga <= 1'b0;
		else
			parallel_tofpga <= next_parallel_tofpga;
	end
end
endgenerate


always_comb begin
	next_parallel_tofpga = parallel_tofpga;

	if(serial_state == Transmit)
		next_parallel_tofpga[actual_bit_ctr] = in_serial;
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// state machine
// ----------------------------------------------------------------------------
// state and data flip-flops for serial clock
always_ff@(negedge serial_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		// state register
		serial_state <= Ready;

		request_word <= 1'b0;

		// counter register
		bit_ctr <= 0;
	end

	// clock
	else begin
		// state register
		serial_state <= next_serial_state;

		request_word <= next_request_word;

		// counter register
		bit_ctr <= next_bit_ctr;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_serial_state = serial_state;
	next_bit_ctr = bit_ctr;
	next_request_word = 1'b0;

`ifdef __IN_SIMULATION__
	$display("** serial: %d, bit %d, ", serial_state/*.name()*/, actual_bit_ctr,
		"from_fpga: %x. **", parallel_fromfpga);
`endif

	// state machine
	unique case(serial_state)
		// wait for enable signal
		Ready: begin
			next_bit_ctr = 0;
			if(in_enable == 1'b1) begin
				next_serial_state = Transmit;
			end
		end

		// serialise parallel data
		Transmit: begin
			// end of word?
			if(bit_ctr == BITS - 1) begin
				next_request_word = 1'b1;
				next_bit_ctr = 0;
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
			end

			// enable signal not active any more?
			if(in_enable == 1'b0) begin
				next_serial_state = Ready;
			end
		end

		default: begin
			next_serial_state = Ready;
		end
	endcase
end
// ----------------------------------------------------------------------------


endmodule
