/**
 * serial controller for asynchronous interface (transmission)
 * @author Tobias Weber
 * @date 8-june-2024
 * @license see 'LICENSE' file
 *
 * references:
 *   - https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter#Data_framing
 */

module serial_async_tx
#(
	// clock frequencies
	parameter MAIN_CLK_HZ   = 50_000_000,
	parameter SERIAL_CLK_HZ = 9_600,

	// inactive signal
	parameter SERIAL_DATA_INACTIVE = 1'b1,

	// word lengths
	parameter BITS         = 8,
	parameter START_BITS   = 1,
	parameter PARITY_BITS  = 0,
	parameter STOP_BITS    = 1,
	parameter LOWBIT_FIRST = 1'b1
 )
(
	// main clock and reset
	input wire in_clk,
	input wire in_rst,

	// not currently transmitting
	output wire out_ready,

	// enable transmission
	input wire in_enable,

	// request next word
	output wire out_next_word,

	// parallel input data (FPGA -> IC)
	input wire [BITS-1 : 0] in_parallel,

	// serial output data (FPGA -> IC)
	output wire out_serial
);


// serial states and next-state logic
typedef enum bit [2 : 0]
{
	Ready, TransmitData,
	TransmitStart, TransmitParity, TransmitStop
} t_tx_state;

t_tx_state tx_state      = Ready;
t_tx_state next_tx_state = Ready;


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


// parallel input buffer (FPGA -> IC)
reg [BITS-1 : 0] parallel_fromfpga = 0, next_parallel_fromfpga = 0;

// serial output (FPGA -> IC)
assign out_serial =
	tx_state == TransmitData ? parallel_fromfpga[actual_bit_ctr] :
	tx_state == TransmitStart ? 1'b0 :
	tx_state == TransmitParity ? 1'b0 :  // TODO
	tx_state == TransmitStop ? 1'b1 :
	SERIAL_DATA_INACTIVE;


reg request_word = 1'b0;
assign out_next_word = request_word;


// generate serial clock
reg serial_clk;

clkgen #(
		.MAIN_CLK_HZ(MAIN_CLK_HZ), .CLK_HZ(SERIAL_CLK_HZ),
		.CLK_INIT(1)
	)
	serial_clk_mod
	(
		.in_clk(in_clk), .in_rst(in_rst),
		.out_clk(serial_clk)
	);


assign out_ready = tx_state == Ready;


// state and data flip-flops for serial clock
always_ff@(negedge serial_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		// state register
		tx_state <= Ready;

		// counter register
		bit_ctr <= 0;

		// parallel data register
		parallel_fromfpga <= 0;
	end

	// clock
	else begin
		// state register
		tx_state <= next_tx_state;

		// counter register
		bit_ctr <= next_bit_ctr;

		// parallel data registers
		parallel_fromfpga <= next_parallel_fromfpga;
	end
end


// input parallel data to register (FPGA -> IC)
always@(in_enable, in_parallel, parallel_fromfpga) begin
	next_parallel_fromfpga <= parallel_fromfpga;

	if(in_enable == 1'b1) begin
		next_parallel_fromfpga <= in_parallel;
	end
end


function t_tx_state state_after_ready(bit enable);
	if(enable == 1'b0) begin
		state_after_ready = Ready;
	end else begin
		if(START_BITS != 1'b0)
			state_after_ready = TransmitStart;
		else
			state_after_ready = TransmitData;
	end
endfunction


function t_tx_state state_after_stop(bit enable);
	if(enable == 1'b1) begin
		if(START_BITS != 1'b0)
			state_after_stop = TransmitStart;
		else
			state_after_stop = TransmitData;
	end else begin
		state_after_stop = Ready;
	end
endfunction


function t_tx_state state_after_parity(bit enable);
	if(STOP_BITS != 1'b0)
		state_after_parity = TransmitStop;
	else
		state_after_parity = state_after_stop(enable);
endfunction


function t_tx_state state_after_transmit(bit enable);
	if(PARITY_BITS != 1'b0)
		state_after_transmit = TransmitParity;
	else
		state_after_transmit = state_after_parity(enable);
endfunction


// state combinatorics
always_comb begin
	// defaults
	next_tx_state = tx_state;
	next_bit_ctr = bit_ctr;
	request_word = 1'b0;

`ifdef __IN_SIMULATION__
	$display("** serial: %s, bit %d. **", tx_state.name(), actual_bit_ctr);
`endif

	// state machine
	case(tx_state)
		// wait for enable signal
		Ready: begin
			next_bit_ctr = 0;
			next_tx_state = state_after_ready(in_enable);
		end

		// transmit start bit(s)
		TransmitStart: begin
			// end of word?
			if(bit_ctr == START_BITS - 1) begin
				next_bit_ctr = 0;
				next_tx_state = TransmitData;
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
			end
		end

		// serialise parallel data
		TransmitData: begin
			// end of word?
			if(bit_ctr == BITS - 1) begin
				request_word = 1'b1;
				next_bit_ctr = 0;
				next_tx_state = state_after_transmit(in_enable);
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
			end
		end

		// transmit parity bit(s)
		TransmitParity: begin
			// end of word?
			if(bit_ctr == PARITY_BITS - 1) begin
				next_bit_ctr = 0;
				next_tx_state = state_after_parity(in_enable);
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
			end
		end

		// transmit stop bit(s)
		TransmitStop: begin
			// end of word?
			if(bit_ctr == STOP_BITS - 1) begin
				next_bit_ctr = 0;
				next_tx_state = state_after_stop(in_enable);
			end else begin
				next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
			end
		end

		default: begin
			next_tx_state = Ready;
		end
	endcase
end


endmodule
