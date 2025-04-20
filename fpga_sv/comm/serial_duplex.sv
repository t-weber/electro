/**
 * serial controller for 3-wire interface with
 *   independent transmission and reception
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 17-aug-2024
 * @license see 'LICENSE' file
 */

module serial_duplex
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

	// enable reception of transmission
	input wire in_enable_tofpga,
	input wire in_enable_fromfpga,

	// request next word (one cycle before current word is finished)
	output wire out_next_word_tofpga,
	output wire out_next_word_fromfpga,

	// current word finished
	output wire out_word_finished_tofpga,
	output wire out_word_finished_fromfpga,

	// parallel input data (FPGA -> IC)
	input wire [BITS - 1 : 0] in_parallel,

	// serial output data (FPGA -> IC)
	output wire out_serial,

	// serial input data (IC -> FPGA)
	input wire in_serial,

	// parallel output data (IC -> FPGA)
	output wire [BITS - 1 : 0] out_parallel
);


// ----------------------------------------------------------------------------
// serial states for transmission and next-state logic
// ----------------------------------------------------------------------------
typedef enum bit [0 : 0] { ReadyTx, Transmit } t_serial_fromfpga_state;

t_serial_fromfpga_state serial_fromfpga_state = ReadyTx;
t_serial_fromfpga_state next_serial_fromfpga_state = ReadyTx;
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// bit counters
// ----------------------------------------------------------------------------
logic [$clog2(BITS) : 0] bit_ctr_fromfpga = 1'b0, next_bit_ctr_fromfpga = 1'b0;
logic [$clog2(BITS) : 0] bit_ctr_tofpga = 1'b0, next_bit_ctr_tofpga = 1'b0;

// bit counter with correct ordering
wire [$clog2(BITS) : 0] actual_bit_ctr_fromfpga, actual_bit_ctr_tofpga;

generate
	if(LOWBIT_FIRST == 1'b1) begin
		assign actual_bit_ctr_fromfpga = bit_ctr_fromfpga;
		assign actual_bit_ctr_tofpga = bit_ctr_tofpga;
	end else begin
		assign actual_bit_ctr_fromfpga =
			$size(bit_ctr_fromfpga)'(BITS - bit_ctr_fromfpga - 1'b1);
		assign actual_bit_ctr_tofpga =
			$size(bit_ctr_tofpga)'(BITS - bit_ctr_tofpga - 1'b1);
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
	// stop serial clock when not transmitting or receiving
	if(SERIAL_CLK_INACTIVE == 1'b1) begin
		// inactive '1' and trigger on rising edge
		assign out_clk =
			serial_fromfpga_state == Transmit || in_enable_tofpga == 1'b1
			? serial_clk
			: 1'b1;
	end else begin
		// inactive '0' and trigger on falling edge
		assign out_clk =
			serial_fromfpga_state == Transmit || in_enable_tofpga == 1'b1
			? ~serial_clk
			: 1'b0;
	end
end
endgenerate
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// output parallel data to register (FPGA -> IC)
// ----------------------------------------------------------------------------
logic [BITS - 1 : 0] parallel_fromfpga = 1'b0, next_parallel_fromfpga = 1'b0;

// serial output (FPGA -> IC)
assign out_serial = serial_fromfpga_state == Transmit
	? parallel_fromfpga[actual_bit_ctr_fromfpga]
	: SERIAL_DATA_INACTIVE;

logic request_word_fromfpga = 1'b0, next_request_word_fromfpga = 1'b0;
assign out_word_finished_fromfpga = request_word_fromfpga;
assign out_next_word_fromfpga = next_request_word_fromfpga;


generate
if(FROM_FPGA_FALLING_EDGE == 1'b1) begin
	always_ff@(negedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1) begin
			// state register
			serial_fromfpga_state <= ReadyTx;

			// data
			parallel_fromfpga <= 1'b0;

			// counter register
			bit_ctr_fromfpga <= 1'b0;
			request_word_fromfpga <= 1'b0;
		end else begin
			// state register
			serial_fromfpga_state <= next_serial_fromfpga_state;

			// data
			parallel_fromfpga <= next_parallel_fromfpga;

			// counter register
			bit_ctr_fromfpga <= next_bit_ctr_fromfpga;
			request_word_fromfpga <= next_request_word_fromfpga;
		end
	end
end else begin
	always_ff@(posedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1) begin
			// state register
			serial_fromfpga_state <= ReadyTx;

			// data
			parallel_fromfpga <= 1'b0;

			// counter register
			bit_ctr_fromfpga <= 1'b0;
			request_word_fromfpga <= 1'b0;
		end else begin
			// state register
			serial_fromfpga_state <= next_serial_fromfpga_state;

			// data
			parallel_fromfpga <= next_parallel_fromfpga;

			// counter register
			bit_ctr_fromfpga <= next_bit_ctr_fromfpga;
			request_word_fromfpga <= next_request_word_fromfpga;
		end
	end
end
endgenerate


always_comb begin
	// defaults
	next_serial_fromfpga_state = serial_fromfpga_state;
	next_parallel_fromfpga = parallel_fromfpga;
	next_bit_ctr_fromfpga = bit_ctr_fromfpga;
	next_request_word_fromfpga = 1'b0;

	if(in_enable_fromfpga == 1'b1)
		next_parallel_fromfpga = in_parallel;

`ifdef __IN_SIMULATION__
	$display("** serial_fromfpga: %d, bit %d, ",
		serial_fromfpga_state/*.name()*/, actual_bit_ctr_fromfpga,
		"%x. **", parallel_fromfpga);
`endif

	unique case(serial_fromfpga_state)
		// wait for enable signal
		ReadyTx: begin
			next_bit_ctr_fromfpga = 1'b0;
			if(in_enable_fromfpga == 1'b1)
				next_serial_fromfpga_state = Transmit;
		end

		// serialise parallel data
		Transmit: begin
			// end of word?
			if(bit_ctr_fromfpga == BITS - 1'b1) begin
				next_request_word_fromfpga = 1'b1;
				next_bit_ctr_fromfpga = 1'b0;
			end else begin
				next_bit_ctr_fromfpga =
					$size(bit_ctr_fromfpga)'(bit_ctr_fromfpga + 1'b1);
			end

			// enable signal not active any more?
			if(in_enable_fromfpga == 1'b0)
				next_serial_fromfpga_state = ReadyTx;
		end

		default: begin
			next_serial_fromfpga_state = ReadyTx;
		end
	endcase
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// buffer serial input (IC -> FPGA)
// ----------------------------------------------------------------------------
// parallel output buffer (IC -> FPGA)
logic [BITS - 1 : 0] parallel_tofpga = 1'b0, next_parallel_tofpga = 1'b0;
assign out_parallel = parallel_tofpga;

logic request_word_tofpga = 1'b0, next_request_word_tofpga = 1'b0;
assign out_word_finished_tofpga = request_word_tofpga;
assign out_next_word_tofpga = next_request_word_tofpga;


generate
if(TO_FPGA_FALLING_EDGE == 1'b1) begin
	always_ff@(negedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1) begin
			// data
			parallel_tofpga <= 1'b0;

			// counter register
			bit_ctr_tofpga <= 1'b0;
			request_word_tofpga <= 1'b0;
		end else begin
			// data
			parallel_tofpga <= next_parallel_tofpga;

			// counter register
			bit_ctr_tofpga <= next_bit_ctr_tofpga;
			request_word_tofpga <= next_request_word_tofpga;
		end
	end
end else begin
	always_ff@(posedge serial_clk, posedge in_rst) begin
		if(in_rst == 1'b1) begin
			// data
			parallel_tofpga <= 1'b0;

			// counter register
			bit_ctr_tofpga <= 1'b0;
			request_word_tofpga <= 1'b0;
		end else begin
			// data
			parallel_tofpga <= next_parallel_tofpga;

			// counter register
			bit_ctr_tofpga <= next_bit_ctr_tofpga;
			request_word_tofpga <= next_request_word_tofpga;
		end
	end
end
endgenerate


always_comb begin
	// defaults
	next_parallel_tofpga = parallel_tofpga;
	next_bit_ctr_tofpga = bit_ctr_tofpga;
	next_request_word_tofpga = 1'b0;

`ifdef __IN_SIMULATION__
	$display("** serial_tofpga: bit %d, ", actual_bit_ctr_tofpga,
		"%x. **", parallel_tofpga);
`endif

	if(in_enable_tofpga == 1'b1) begin
		next_parallel_tofpga[actual_bit_ctr_tofpga] = in_serial;

		// end of word?
		if(bit_ctr_tofpga == BITS - 1'b1) begin
			next_request_word_tofpga = 1'b1;
			next_bit_ctr_tofpga = 1'b0;
		end else begin
			next_bit_ctr_tofpga =
				$size(bit_ctr_tofpga)'(bit_ctr_tofpga + 1'b1);
		end
	end else begin
		next_bit_ctr_tofpga = 1'b0;
	end
end
// ----------------------------------------------------------------------------

endmodule
