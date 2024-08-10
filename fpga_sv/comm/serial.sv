/**
 * serial controller for 3-wire interface
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
	parameter SERIAL_CLK_INACTIVE     = 1'b1,
	parameter SERIAL_DATA_INACTIVE    = 1'b1,
	parameter KEEP_SERIAL_CLK_RUNNING = 1'b0,

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

	// not currently transmitting
	output wire out_ready,

	// enable transmission
	input wire in_enable,

	// request next word
	output wire out_next_word,

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
typedef enum bit [0 : 0] { Ready, Transmit } t_serial_state;

t_serial_state serial_state      = Ready;
t_serial_state next_serial_state = Ready;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// bit counter
reg [$clog2(BITS) : 0] bit_ctr = 0, next_bit_ctr = 0;

// bit counter with correct ordering
wire [$clog2(BITS) : 0] actual_bit_ctr;

generate
	if(LOWBIT_FIRST == 1'b1) begin
		assign actual_bit_ctr = bit_ctr;
	end else begin
		assign actual_bit_ctr = $size(bit_ctr)'(BITS - bit_ctr - 1);
	end
endgenerate
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// parallel input buffer (FPGA -> IC)
reg [BITS-1 : 0] parallel_fromfpga = 0, next_parallel_fromfpga = 0;

// serial output (FPGA -> IC)
assign out_serial = serial_state == Transmit
	? parallel_fromfpga[actual_bit_ctr]
	: SERIAL_DATA_INACTIVE;


// parallel output buffer (IC -> FPGA)
reg [BITS-1 : 0] parallel_tofpga = 0, next_parallel_tofpga = 0;
assign out_parallel = parallel_tofpga;

reg request_word = 1'b0;
assign out_next_word = request_word;


assign out_ready = serial_state == Ready;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// generate serial clock
reg serial_clk;

clkgen #(
		.MAIN_CLK_HZ(MAIN_CLK_HZ), .CLK_HZ(SERIAL_CLK_HZ),
		.CLK_INIT(1'b1)
	)
	serial_clk_mod
	(
		.in_clk(in_clk), .in_rst(in_rst),
		.out_clk(serial_clk)
	);


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


// state and data flip-flops for serial clock
always_ff@(negedge serial_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		// state register
		serial_state <= Ready;

		// counter register
		bit_ctr <= 0;

		// parallel data register
		parallel_fromfpga <= 0;
		parallel_tofpga <= 0;
	end

	// clock
	else begin
		// state register
		serial_state <= next_serial_state;

		// counter register
		bit_ctr <= next_bit_ctr;

		// parallel data registers
		parallel_fromfpga <= next_parallel_fromfpga;
		parallel_tofpga <= next_parallel_tofpga;
	end
end


// input parallel data to register (FPGA -> IC)
always_comb begin
	next_parallel_fromfpga = parallel_fromfpga;

	if(in_enable == 1'b1) begin
		next_parallel_fromfpga = in_parallel;
	end
end


// buffer serial input (IC -> FPGA)
always_comb begin
	next_parallel_tofpga = parallel_tofpga;

	if(serial_state == Transmit) begin
		next_parallel_tofpga[actual_bit_ctr] = in_serial;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_serial_state = serial_state;
	next_bit_ctr = bit_ctr;
	request_word = 1'b0;

//`ifdef __IN_SIMULATION__
//	$display("** serial: %s, bit %d. **", serial_state.name(), actual_bit_ctr);
//`endif

	// state machine
	case(serial_state)
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
				request_word = 1'b1;
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


endmodule
