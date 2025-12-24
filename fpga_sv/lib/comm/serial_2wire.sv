/**
 * serial controller for 2-wire interface
 * @author Tobias Weber <tobias.weber@tum.de> (0000-0002-7230-1932)
 * @date 1-may-2024
 * @license see 'LICENSE' file
 */

module serial_2wire
#(
	// clock frequencies
	parameter longint MAIN_CLK_HZ   = 50_000_000,
	parameter longint SERIAL_CLK_HZ = 10_000,

	// address and word lengths
	parameter byte ADDR_BITS    = 8,
	parameter byte BITS         = 8,
	parameter bit LOWBIT_FIRST  = 1'b1,

	// transmit target read/write addresses?
	parameter bit TRANSMIT_ADDR = 1'b1,

	// continue after errors
	parameter bit IGNORE_ERROR  = 1'b0
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// serial clock and data
	inout wire inout_serial_clk,
	inout wire inout_serial,

	// enable transmission
	input wire in_enable,
	input wire in_write,

	// ready and error flag
	output wire out_ready,
	output wire out_err,

	// request next word (one cycle before current word is finished)
	output wire out_next_word,

	// current word finished
	output wire out_word_finished,

	// target addresses for writing and reading
	input wire [ADDR_BITS - 1 : 0] in_addr_write,
	input wire [ADDR_BITS - 1 : 0] in_addr_read,

	// parallel input data (FPGA -> IC)
	input wire [BITS - 1 : 0] in_parallel,

	// parallel output data (IC -> FPGA)
	output wire [BITS - 1 : 0] out_parallel
);


// ============================================================================
// serial states and next-state logic
// ============================================================================
typedef enum
{
	Ready, Error,
	TransmitWriteAddress, TransmitReadAddress,
	Transmit, Receive,
	SendStart, SendStart2, SendRepeatedStart,
	SendStop, SendStop2,
	ReceiveAck, SendAck, SendNoAck
} t_serial_state;

t_serial_state serial_state = Ready, next_serial_state = Ready;
t_serial_state state_afterstart = Ready, next_state_afterstart = Ready;
t_serial_state state_afterstop = Ready, next_state_afterstop = Ready;
t_serial_state state_afterack = Ready, next_state_afterack = Ready;
// ============================================================================


// ============================================================================
// bit counter
// ============================================================================
reg [$clog2(BITS) : 0] bit_ctr = 0, next_bit_ctr = 0;

// bit counter with correct ordering
wire [$clog2(BITS) : 0] actual_bit_ctr;

generate
	if(LOWBIT_FIRST == 1'b1) begin
		assign actual_bit_ctr = bit_ctr;
	end else begin
		assign actual_bit_ctr = $size(actual_bit_ctr)'(BITS - bit_ctr - 1'b1);
	end
endgenerate
// ============================================================================


reg request_word = 1'b0, next_request_word = 1'b0;
assign out_word_finished = request_word;
assign out_next_word = next_request_word;

reg ready = 1'b0;
assign out_ready = ready;

reg err = 1'b0;
assign out_err = err;


// ============================================================================
// generate serial clock
// TODO: use external or PLL clock to avoid combinational glitches
// ============================================================================
logic serial_clk, serial_fe;

// generate serial clock
clkpulsegen #(
		.MAIN_CLK_HZ(MAIN_CLK_HZ), .CLK_HZ(SERIAL_CLK_HZ),
		.CLK_INIT(1'b1)
	)
	serial_clk_mod
	(
		.in_clk(in_clk), .in_rst(in_rst),
		.out_clk(serial_clk), .out_re(), .out_fe(serial_fe)
	);


// output serial clock
assign inout_serial_clk =
	(serial_state == Transmit || serial_state == Receive ||
	serial_state == TransmitWriteAddress || serial_state == TransmitReadAddress ||
	serial_state == ReceiveAck || serial_state == SendAck || serial_state == SendNoAck ||
	serial_state == SendStop || serial_state == SendRepeatedStart)
	&& serial_clk == 1'b0 ? 1'b0 : 1'bz;
// ============================================================================


// ============================================================================
// data transfer IC -> FPGA
// ============================================================================
// parallel output buffer (IC -> FPGA)
reg [BITS - 1 : 0] parallel_tofpga = 0, next_parallel_tofpga = 0;
assign out_parallel = parallel_tofpga;


// buffer serial input (IC -> FPGA)
always_comb begin
	next_parallel_tofpga = parallel_tofpga;

	if(serial_state == Receive) begin
		next_parallel_tofpga[actual_bit_ctr] = inout_serial;
	end
end
// ============================================================================


// ============================================================================
// state and data flip-flops for serial clock
// ============================================================================

always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		// state registers
		serial_state <= Ready;
		state_afterstart <= Ready;
		state_afterstop <= Ready;
		state_afterack <= Ready;

		request_word <= 1'b0;

		// counter register
		bit_ctr <= 1'b0;

		// parallel data registers
		parallel_fromfpga <= 1'b0;
		parallel_tofpga <= 1'b0;
	end

	// clock
	else begin
			if(serial_fe == 1'b1) begin
				// state registers
				serial_state <= next_serial_state;
				state_afterstart <= next_state_afterstart;
				state_afterstop <= next_state_afterstop;
				state_afterack <= next_state_afterack;

				request_word <= next_request_word;

				// counter register
				bit_ctr <= next_bit_ctr;

				// parallel data registers
				parallel_fromfpga <= next_parallel_fromfpga;
				parallel_tofpga <= next_parallel_tofpga;
			end
		end
end
// ============================================================================


// ============================================================================
// data transfer FPGA -> IC
// ============================================================================
// parallel input buffer (FPGA -> IC)
reg [BITS - 1 : 0] parallel_fromfpga = 0, next_parallel_fromfpga = 0;

// input parallel data to register (FPGA -> IC)
always_comb begin
	next_parallel_fromfpga = parallel_fromfpga;

	if(in_enable == 1'b1)
		next_parallel_fromfpga = in_parallel;
end


logic serial_out = 1'b1;
assign inout_serial = (serial_out == 1'b0 ? 1'b0 : 1'bz);


// output serial data (FPGA -> IC)
always_comb begin
	unique case(serial_state)
		// ------------------------------------------------------------
		// write target address
		// ------------------------------------------------------------
		TransmitWriteAddress: begin
			serial_out = in_addr_write[actual_bit_ctr]; 
		end

		TransmitReadAddress: begin
			serial_out = in_addr_read[actual_bit_ctr];
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// serialise parallel data and sent it to target
		// ------------------------------------------------------------
		Transmit: begin
			serial_out = parallel_fromfpga[actual_bit_ctr];
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// send start signal
		// ------------------------------------------------------------
		SendStart: begin
			serial_out = 1'b1;
		end

		SendStart2: begin
			serial_out = 1'b0;
		end

		SendRepeatedStart: begin
			// same as SendStart, but with serial clock active
			serial_out = 1'b1;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// send stop signal
		// ------------------------------------------------------------
		SendStop: begin
			serial_out = 1'b0;
		end

		SendStop2: begin
			serial_out = 1'b1;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// receive or send acknowledge signal
		// ------------------------------------------------------------
		SendAck: begin
			serial_out = 1'b0;
		end

		SendNoAck: begin
			serial_out = 1'b1;
		end
		// ------------------------------------------------------------

		default: begin
			serial_out = 1'b1;
		end
	endcase
end
// ============================================================================


// ============================================================================
// state combinatorics
// ============================================================================
always_comb begin
	// defaults
	next_serial_state = serial_state;
	next_state_afterstart = state_afterstart;
	next_state_afterstop = state_afterstop;
	next_state_afterack = state_afterack;
	next_bit_ctr = bit_ctr;

	next_request_word = 1'b0;

	ready = 1'b0;
	err = 1'b0;

`ifdef __IN_SIMULATION__
	$display("serial_2wire: %s", serial_state.name());
`endif

	unique case(serial_state)
		// wait for enable signal
		Ready: begin
			next_bit_ctr = 0;
			if(in_enable == 1'b1) begin
				next_serial_state = SendStart;
				if(TRANSMIT_ADDR == 1'b1)
					next_state_afterstart = TransmitWriteAddress;
				else
					next_state_afterstart = Transmit;
			end else begin
				ready = 1'b1;
			end
		end

		Error: begin
			err = 1;
		end

		// ------------------------------------------------------------
		// write target address
		// ------------------------------------------------------------
		TransmitWriteAddress: begin
			// end of word?
			if(bit_ctr == ADDR_BITS - 1) begin
				next_bit_ctr = 0;

				next_serial_state = ReceiveAck;
				next_state_afterack = Transmit;
			end else begin
				// next bit of the word
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1);
			end
		end

		TransmitReadAddress: begin
			// end of word?
			if(bit_ctr == ADDR_BITS - 1) begin
				next_bit_ctr = 0;

				next_serial_state = ReceiveAck;
				next_state_afterack = Receive;
			end else begin
				// next bit of the word
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1);
			end
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// serialise parallel data and sent it to target
		// ------------------------------------------------------------
		Transmit: begin
			// end of word?
			if(bit_ctr == BITS - 1) begin
				next_request_word = 1'b1;
				next_bit_ctr = 0;

				next_serial_state = ReceiveAck;
				if(in_write == 1'b1) begin
					next_state_afterack = Transmit;
				end else begin
					next_state_afterack = SendRepeatedStart;
					if(TRANSMIT_ADDR == 1'b1)
						next_state_afterstart = TransmitReadAddress;
					else
						next_state_afterstart = Receive;
				end
			end else begin
				// next bit of the word
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1);
			end

			// enable signal not active any more?
			if(in_enable == 1'b0) begin
				if (bit_ctr == BITS - 1) begin
					next_serial_state = ReceiveAck;
					next_state_afterack = SendStop;
				end else begin
					next_serial_state = SendStop;
				end
				next_state_afterstop = Ready;
			end
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// read serial data from target
		// ------------------------------------------------------------
		Receive: begin
			// end of word?
			if(bit_ctr == BITS - 1) begin
				next_request_word = 1'b1;
				next_bit_ctr = 0;

				next_serial_state = SendAck;
				next_state_afterack = Receive;
			end else begin
				// next bit of the word
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1);
			end

			// enable signal not active any more?
			if(in_enable == 1'b0) begin
				if (bit_ctr == BITS - 1) begin
					next_serial_state = SendNoAck;
					next_state_afterack = SendStop;
				end else begin
					next_serial_state = SendStop;
				end
				next_state_afterstop = Ready;
			end
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// send start signal
		// ------------------------------------------------------------
		SendStart: begin
			next_serial_state = SendStart2;
		end

		SendStart2: begin
			next_serial_state = state_afterstart;
		end

		SendRepeatedStart: begin
			next_serial_state = SendStart2;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// send stop signal
		// ------------------------------------------------------------
		SendStop: begin
			next_serial_state = SendStop2;
		end

		SendStop2: begin
			next_serial_state = state_afterstop;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// receive or send acknowledge signal
		// ------------------------------------------------------------
		ReceiveAck: begin
			if(inout_serial == 1'b0 || IGNORE_ERROR == 1'b1) begin
				next_serial_state = state_afterack;
			end else begin
				next_serial_state = Error;
			end
		end

		SendAck: begin
			next_serial_state = state_afterack;
		end

		SendNoAck: begin
			next_serial_state = state_afterack;
		end
		// ------------------------------------------------------------

		default: begin
			next_serial_state = Ready;
		end
	endcase
end
// ============================================================================


endmodule
