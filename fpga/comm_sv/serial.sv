/**
 * serial controller for 3-wire protocol
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

	output wire out_clk,
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


// serial states and next-state logic
typedef enum bit [1 : 0] { Ready, Transmit } t_serial_state;
t_serial_state serial_state      = Ready;
t_serial_state next_serial_state = Ready;

// serial clock
reg serial_clk;

// bit counter
reg [$clog2(BITS) : 0] bit_ctr = 0, next_bit_ctr = 0;

// bit counter with correct ordering
wire [$clog2(BITS) : 0] actual_bit_ctr;

generate
	if(LOWBIT_FIRST == 1) begin
		assign actual_bit_ctr = bit_ctr;
	end else begin
		assign actual_bit_ctr = BITS - bit_ctr - 1;
	end
endgenerate


// parallel input buffer (FPGA -> IC)
reg [BITS-1 : 0] parallel_fromfpga = 0, next_parallel_fromfpga = 0;

// serial output buffer (FPGA -> IC)
reg serial_fromfpga = SERIAL_DATA_INACTIVE;
assign out_serial = serial_fromfpga;

// parallel output buffer (IC -> FPGA)
reg [BITS-1 : 0] parallel_tofpga = 0, next_parallel_tofpga = 0;
assign out_parallel = parallel_tofpga;

reg request_word = 0;
assign out_next_word = request_word;


// generate serial clock
clkgen #(
		.MAIN_CLK_HZ(MAIN_CLK_HZ), .CLK_HZ(SERIAL_CLK_HZ),
		.CLK_INIT(1)
	)
	serial_clk_mod
	(
		.in_clk(in_clk), .in_rst(in_rst),
		.out_clk(serial_clk)
	);


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
		parallel_fromfpga <= 0;
		parallel_tofpga <= 0;
	end

	// clock
	else if(in_clk == 1) begin
		// parallel data register
		parallel_fromfpga <= next_parallel_fromfpga;
		parallel_tofpga <= next_parallel_tofpga;
	end
end


// input parallel data to register (FPGA -> IC)
always@(in_enable, in_parallel, parallel_fromfpga) begin
	next_parallel_fromfpga <= parallel_fromfpga;

	if(in_enable == 1) begin
		next_parallel_fromfpga <= in_parallel;
	end
end


// registered output (FPGA -> IC)
always_ff@(posedge in_clk) begin
	serial_fromfpga <= SERIAL_DATA_INACTIVE;

	if(next_serial_state == Transmit) begin
		// output current bit
		serial_fromfpga <= parallel_fromfpga[actual_bit_ctr];
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
	request_word = 0;

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
			// end of word?
			if(bit_ctr == BITS - 1) begin
				request_word = 1;
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
