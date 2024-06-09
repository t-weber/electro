/**
 * serial controller for asynchronous interface (reception)
 * @author Tobias Weber
 * @date 9-june-2024
 * @license see 'LICENSE' file
 *
 * references:
 *   - https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter#Data_framing
 */

module serial_async_rx
#(
	// clock frequencies
	parameter MAIN_CLK_HZ   = 50_000_000,
	parameter SERIAL_CLK_HZ = 9_600,

	// sampling clock multiplier
	parameter CLK_MULTIPLE  = 8,

	// constants
	parameter SERIAL_START  = 1'b0,
	parameter SERIAL_STOP   = 1'b1,

	// word lengths
	parameter BITS          = 8,
	parameter START_BITS    = 1,
	parameter PARITY_BITS   = 0,
	parameter STOP_BITS     = 1,
	parameter LOWBIT_FIRST  = 1'b1
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// not currently receiving
	output wire out_ready,

	// enable reception
	input wire in_enable,

	// next word ready
	output wire out_next_word,

	// serial input data (IC -> FPGA)
	input wire in_serial,

	// parallel output data (IC -> FPGA)
	output wire [BITS-1 : 0] out_parallel
);


// serial states and next-state logic
typedef enum bit [3 : 0]
{
	Ready, Error, WaitCycle,
	ReceiveData,
	ReceiveStartCont, ReceiveStart,
	ReceiveParity, ReceiveStop
} t_rx_state;

t_rx_state rx_state         = Ready;
t_rx_state next_rx_state    = Ready;
t_rx_state state_after_wait = Ready;


// clock multipe counter
reg [$clog2(CLK_MULTIPLE) : 0] multi_ctr = 0, next_multi_ctr = 0;

// bit counter
reg [$clog2(BITS) : 0] bit_ctr = 0, next_bit_ctr = 0;

// bit counter with correct ordering
wire [$clog2(BITS) : 0] actual_bit_ctr;

generate
	if(LOWBIT_FIRST == 1'b1) begin
		assign actual_bit_ctr = bit_ctr;
	end else begin
		assign actual_bit_ctr = $size(bit_ctr)'(BITS - bit_ctr - 1'b1);
	end
endgenerate


// parallel output buffer (IC -> FPGA)
reg [BITS-1 : 0] parallel_tofpga = 0, next_parallel_tofpga = 0;
assign out_parallel = parallel_tofpga;

reg request_word = 1'b0;
assign out_next_word = request_word;


// generate serial clock
reg serial_clk;

clkgen #(
		.MAIN_CLK_HZ(MAIN_CLK_HZ),
		.CLK_HZ(SERIAL_CLK_HZ * CLK_MULTIPLE),
		.CLK_INIT(1)
	)
	serial_clk_mod
	(
		.in_clk(in_clk), .in_rst(in_rst),
		.out_clk(serial_clk)
	);


assign out_ready = rx_state == Ready;


// state and data flip-flops for serial clock
always_ff@(posedge serial_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		// state register
		rx_state <= Ready;

		// counter registers
		bit_ctr <= 0;
		multi_ctr <= 0;

		// parallel data register
		parallel_tofpga <= 0;
	end

	// clock
	else begin
		// state register
		rx_state <= next_rx_state;

		// counter registers
		bit_ctr <= next_bit_ctr;
		multi_ctr <= next_multi_ctr;

		// parallel data registers
		parallel_tofpga <= next_parallel_tofpga;
	end
end


function t_rx_state state_after_ready(bit enable);
	if(enable == 1'b0) begin
		state_after_ready = Ready;
	end else begin
		if(START_BITS != 1'b0)
			state_after_ready = ReceiveStartCont;
		else
			state_after_ready = ReceiveData;
	end
endfunction


function t_rx_state state_after_start(bit enable);
	if(enable == 1'b1) begin
		state_after_start = ReceiveData;
	end else begin
		state_after_start = Ready;
	end
endfunction


function t_rx_state state_after_stop(bit enable);
	if(enable == 1'b1) begin
		if(START_BITS != 1'b0)
			state_after_stop = ReceiveStart;
		else
			state_after_stop = ReceiveData;
	end else begin
		state_after_stop = Ready;
	end
endfunction


function t_rx_state state_after_parity(bit enable);
	if(STOP_BITS != 1'b0)
		state_after_parity = ReceiveStop;
	else
		state_after_parity = state_after_stop(enable);
endfunction


function t_rx_state state_after_receive(bit enable);
	if(PARITY_BITS != 1'b0)
		state_after_receive = ReceiveParity;
	else
		state_after_receive = state_after_parity(enable);
endfunction


// state combinatorics
always_comb begin
	// defaults
	next_rx_state = rx_state;
	next_bit_ctr = bit_ctr;
	next_multi_ctr = multi_ctr;
	next_parallel_tofpga = parallel_tofpga;
	request_word = 1'b0;

`ifdef __IN_SIMULATION__
	$display("**** serial_async_rx: %s, bit %d, clk_mult %d. ****",
		rx_state.name(), actual_bit_ctr, multi_ctr);
`endif

	// state machine
	case(rx_state)
		// wait for enable signal
		Ready: begin
			next_bit_ctr = 0;
			next_rx_state = state_after_ready(in_enable);
		end

		// error
		Error: begin
		end

		// move to the middle of the next serial signal
		WaitCycle: begin
			// also count in the clock cycle lost by changing states
			if(multi_ctr == CLK_MULTIPLE - 2'd2) begin
				next_rx_state = state_after_wait;
				next_multi_ctr = 0;
			end else begin
				next_multi_ctr = $size(multi_ctr)'(multi_ctr + 1'b1);
			end
		end

		// receive start bit(s), probing at every cycle
		// until the middle of the last start bit
		ReceiveStartCont: begin
			if(in_serial == SERIAL_START) begin
				// at the middle of the last start bit?
				if(multi_ctr == CLK_MULTIPLE / 2 //- 1'b1
					&& bit_ctr == START_BITS - 1'b1) begin
					state_after_wait = state_after_start(in_enable);
					next_rx_state = WaitCycle;
					next_bit_ctr = 0;
					next_multi_ctr = 0;

				// end of clock multiplier?
				end else if(multi_ctr == CLK_MULTIPLE - 1'b1) begin
					next_multi_ctr = 0;
					next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);

				// next clock multiplier
				end else begin
					next_multi_ctr = $size(multi_ctr)'(multi_ctr + 1'b1);
				end
			end else begin
				next_bit_ctr = 0;
				next_multi_ctr = 0;

				if(in_enable == 1'b0)
					next_rx_state = Ready;
			end
		end

		// receive start bit(s), only probing once
		ReceiveStart: begin
			next_rx_state = WaitCycle;

			if(in_serial == SERIAL_START) begin
				// end of word?
				if(bit_ctr == START_BITS - 1'b1) begin
					next_bit_ctr = 0;
					state_after_wait = state_after_start(in_enable);
				end else begin
					next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
					state_after_wait = ReceiveStart;
				end
			end else begin
				if(in_enable == 1'b0)
					next_rx_state = Ready;
				else
					state_after_wait = ReceiveStart;
			end
		end

		// serialise parallel data
		ReceiveData: begin
			next_parallel_tofpga[actual_bit_ctr] = in_serial;
			next_rx_state = WaitCycle;

			// end of word?
			if(bit_ctr == BITS - 1'b1) begin
				request_word = 1'b1;
				next_bit_ctr = 0;
				state_after_wait = state_after_receive(in_enable);
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
				state_after_wait = ReceiveData;
			end
		end

		// receive parity bit(s)
		ReceiveParity: begin
			// TODO: test parity
			next_rx_state = WaitCycle;

			// end of word?
			if(bit_ctr == PARITY_BITS - 1'b1) begin
				next_bit_ctr = 0;
				state_after_wait = state_after_parity(in_enable);
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
				state_after_wait = ReceiveParity;
			end
		end

		// receive stop bit(s)
		ReceiveStop: begin
			if(in_serial == SERIAL_STOP) begin
				next_rx_state = WaitCycle;

				// end of word?
				if(bit_ctr == STOP_BITS - 1'b1) begin
					next_bit_ctr = 0;
					state_after_wait = state_after_stop(in_enable);
				end else begin
					next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
					state_after_wait = ReceiveStop;
				end
			end else begin
				next_rx_state = Error;
			end
		end

		default: begin
			next_rx_state = Ready;
		end
	endcase
end


endmodule
