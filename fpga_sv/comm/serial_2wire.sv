/**
 * serial controller for 2-wire interface
 * @author Tobias Weber
 * @date 1-may-2024
 * @license see 'LICENSE' file
 */

module serial_2wire
#(
	// clock frequencies
	parameter MAIN_CLK_HZ   = 50_000_000,
	parameter SERIAL_CLK_HZ = 10_000,

	// address and word lengths
	parameter ADDR_BITS     = 8,
	parameter BITS          = 8,
	parameter LOWBIT_FIRST  = 1,

	// continue after errors
	parameter IGNORE_ERROR  = 0
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// serial clock and data
	inout wire inout_clk,
	inout wire inout_serial,

	// enable transmission
	input wire in_enable,
	input wire in_write,

	// ready and error flag
	output wire out_ready,
	output wire out_err,

	// request next word
	output wire out_next_word,

	// target addresses for writing and reading
	input wire [ADDR_BITS-1 : 0] in_addr_write,
	input wire [ADDR_BITS-1 : 0] in_addr_read,

	// parallel input data (FPGA -> IC)
	input wire [BITS-1 : 0] in_parallel,

	// parallel output data (IC -> FPGA)
	output wire [BITS-1 : 0] out_parallel
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
reg [$clog2(BITS) : 0] actual_bit_ctr;

generate
	if(LOWBIT_FIRST == 1) begin
		assign actual_bit_ctr = bit_ctr;
	end else begin
		assign actual_bit_ctr = BITS - bit_ctr - 1;
	end
endgenerate
// ============================================================================


reg request_word = 1'b0;
assign out_next_word = request_word;

reg ready = 1'b0;
assign out_ready = ready;

reg err = 1'b0;
assign out_err = err;


// ============================================================================
// generate serial clock
// ============================================================================
reg serial_clk;

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
assign inout_clk =
	(serial_state == Transmit || serial_state == Receive ||
	serial_state == TransmitWriteAddress || serial_state == TransmitReadAddress ||
	serial_state == ReceiveAck || serial_state == SendAck || serial_state == SendNoAck ||
	serial_state == SendStop || serial_state == SendRepeatedStart)
	? (serial_clk == 1'b0 ? 1'b0 : 1'bZ) : 1'bZ;
// ============================================================================


// ============================================================================
// data transfer IC -> FPGA
// ============================================================================
// parallel output buffer (IC -> FPGA)
reg [BITS-1 : 0] parallel_tofpga = 0, next_parallel_tofpga = 0;
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
always_ff@(negedge serial_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1) begin
		// state registers
		serial_state <= Ready;
		state_afterstart <= Ready;
		state_afterstop <= Ready;
		state_afterack <= Ready;

		// counter register
		bit_ctr <= 0;

		// parallel data registers
		parallel_fromfpga <= 0;
		parallel_tofpga <= 0;
	end

	// clock
	else if(serial_clk == 0) begin
		// state registers
		serial_state <= next_serial_state;
		state_afterstart <= next_state_afterstart;
		state_afterstop <= next_state_afterstop;
		state_afterack <= next_state_afterack;

		// counter register
		bit_ctr <= next_bit_ctr;

		// parallel data registers
		parallel_fromfpga <= next_parallel_fromfpga;
		parallel_tofpga <= next_parallel_tofpga;
	end
end
// ============================================================================


// ============================================================================
// data transfer FPGA -> IC
// ============================================================================
// parallel input buffer (FPGA -> IC)
reg [BITS-1 : 0] parallel_fromfpga = 0, next_parallel_fromfpga = 0;

// input parallel data to register (FPGA -> IC)
always@(in_write, in_parallel, parallel_fromfpga) begin
	next_parallel_fromfpga <= parallel_fromfpga;

	//if(in_write == 1)
		next_parallel_fromfpga <= in_parallel;
end


reg serial_out = 1'bZ;
assign inout_serial = serial_out;


// output serial data (FPGA -> IC)
always_comb begin
	case(serial_state)
		// ------------------------------------------------------------
		// write target address
		// ------------------------------------------------------------
		TransmitWriteAddress: begin
			if(in_addr_write[actual_bit_ctr] == 1'b0)
				serial_out = 1'b0;
			else
				serial_out = 1'bZ;
		end

		TransmitReadAddress: begin
			if(in_addr_read[actual_bit_ctr] == 1'b0)
				serial_out = 1'b0;
			else
				serial_out = 1'bZ;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// serialise parallel data and sent it to target
		// ------------------------------------------------------------
		Transmit: begin
			if(parallel_fromfpga[actual_bit_ctr] == 1'b0)
				serial_out = 1'b0;
			else
				serial_out = 1'bZ;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// send start signal
		// ------------------------------------------------------------
		SendStart: begin
			serial_out = 1'bZ;
		end

		SendStart2: begin
			serial_out = 1'b0;
		end

		SendRepeatedStart: begin
			// same as SendStart, but with serial clock active
			serial_out = 1'bZ;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// send stop signal
		// ------------------------------------------------------------
		SendStop: begin
			serial_out = 1'b0;
		end

		SendStop2: begin
			serial_out = 1'bZ;
		end
		// ------------------------------------------------------------

		// ------------------------------------------------------------
		// receive or send acknowledge signal
		// ------------------------------------------------------------
		SendAck: begin
			serial_out = 1'b0;
		end

		SendNoAck: begin
			serial_out = 1'bZ;
		end
		// ------------------------------------------------------------

		default: begin
			serial_out = 1'bZ;
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

	request_word = 1'b0;
	ready = 1'b0;
	err = 1'b0;

	$display("serial_2wire: %s", serial_state.name());

	case(serial_state)
		// wait for enable signal
		Ready: begin
			next_bit_ctr = 0;
			if(in_enable == 1) begin
				next_serial_state = SendStart;
				next_state_afterstart = TransmitWriteAddress;
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
				request_word = 1'b1;
				next_bit_ctr = 0;

				next_serial_state = ReceiveAck;
				if(in_write == 1) begin
					next_state_afterack = Transmit;
				end else begin
					next_state_afterack = SendRepeatedStart;
					next_state_afterstart = TransmitReadAddress;
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
				request_word = 1'b1;
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
			if(inout_serial == 1'b0 || IGNORE_ERROR == 1) begin
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
