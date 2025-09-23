/**
 * sends an echo via serial communication (test: screen /dev/tty.usbserial-142101 115200)
 * @author Tobias Weber
 * @date 8-june-2024
 * @license see 'LICENSE' file
 */

module serial_async
(
	// main clock
	input clk27,

	// serial interface
	output serial_tx,
	input serial_rx,

	// keys and leds
	input [1:0] key,
	output [5:0] led
);


localparam MAIN_CLK     = 27_000_000;
localparam SERIAL_CLK   =    115_200;

localparam BITS         = 8;
localparam CLK_MULTIPLE = 16;
localparam CLK_TOCHECK  = 8;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
logic rst, toggled;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(toggled), .out_debounced());
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
logic slow_clk;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(1))
clk_test (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// serial interface
// ----------------------------------------------------------------------------
logic [BITS - 1 : 0] char_tx, next_char_tx = 0;
logic [BITS - 1 : 0] char_rx;
wire [BITS - 1 : 0] char_cur;

logic enabled_tx, enabled_rx;
logic ready_tx, ready_rx;

logic word_finished_tx, last_word_finished_tx = 1'b0;
logic word_finished_rx, last_word_finished_rx = 1'b0;

wire bus_cycle_tx_next = word_finished_tx && ~last_word_finished_tx;
wire bus_cycle_rx_next = word_finished_rx && ~last_word_finished_rx;

logic [$clog2(BITS) : 0] bit_ctr = 0, next_bit_ctr = 0;


// instantiate serial transmitter
serial_async_tx #(
	.BITS(BITS), .LOWBIT_FIRST(1'b1),
	.MAIN_CLK_HZ(MAIN_CLK),
	.SERIAL_CLK_HZ(SERIAL_CLK)
)
serial_tx_mod(
	.in_clk(clk27), .in_rst(rst),
	.in_enable(enabled_tx), .out_ready(ready_tx),
	.in_parallel(char_cur), .out_serial(serial_tx),
	//.out_next_word(word_finished_tx)
	.out_word_finished(word_finished_tx)
);


// instantiate serial receiver
serial_async_rx #(
	.BITS(BITS), .LOWBIT_FIRST(1'b1),
	.MAIN_CLK_HZ(MAIN_CLK),
	.SERIAL_CLK_HZ(SERIAL_CLK),
	.CLK_MULTIPLE(CLK_MULTIPLE), .CLK_TOCHECK(CLK_TOCHECK)
)
serial_rx_mod(
	.in_clk(clk27), .in_rst(rst),
	.in_enable(enabled_rx), .in_serial(serial_rx),
	.out_parallel(char_rx), .out_ready(ready_rx),

	// need to be sure the word is finished now
	// (and not only in the next cycle) because the
	// main clock is faster than the serial clock
	//.out_next_word(word_finished_rx),
	.out_word_finished(word_finished_rx),
);


// states
typedef enum bit [2 : 0]
{
	ReceiveData, TransmitData, TransmitBit,
	TransmitSpace, TransmitCR, TransmitNL,
} t_state;
t_state state = ReceiveData, next_state = ReceiveData;


// state flip-flops
always_ff@(posedge clk27, posedge rst) begin
	// reset
	if(rst == 1'b1) begin
		state <= ReceiveData;
		char_tx <= 0;
		last_word_finished_tx <= 1'b0;
		last_word_finished_rx <= 1'b0;
		bit_ctr <= 0;
	end

	// clock
	else begin
		state <= next_state;
		char_tx <= next_char_tx;
		last_word_finished_tx <= word_finished_tx;
		last_word_finished_rx <= word_finished_rx;
		bit_ctr <= next_bit_ctr;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_char_tx = char_tx;
	next_bit_ctr = bit_ctr;

	enabled_rx = 1'b0;
	enabled_tx = 1'b0;

	unique case(state)
		ReceiveData: begin
			enabled_rx = 1'b1;
			if(bus_cycle_rx_next == 1'b1) begin
				next_char_tx = char_rx;
				next_state = TransmitData;
			end
		end

		TransmitData: begin
			enabled_tx = 1'b1;
			if(bus_cycle_tx_next == 1'b1) begin
				enabled_tx = 1'b0;
				next_state = TransmitSpace;
			end
		end

		TransmitSpace: begin
			enabled_tx = 1'b1;
			if(bus_cycle_tx_next == 1'b1) begin
				enabled_tx = 1'b0;
				next_bit_ctr <= 0;
				next_state = TransmitBit;
			end
		end

		TransmitBit: begin
			enabled_tx = 1'b1;
			if(bus_cycle_tx_next == 1'b1) begin
				enabled_tx = 1'b0;

				if(bit_ctr == BITS - 1) begin
					next_state = TransmitCR;
					next_bit_ctr = 0;
				end else begin
					next_bit_ctr = $size(bit_ctr)'(bit_ctr + 1'b1);
				end
			end
		end

		TransmitCR: begin
			enabled_tx = 1'b1;
			if(bus_cycle_tx_next == 1'b1) begin
				enabled_tx = 1'b0;
				next_state = TransmitNL;
			end
		end

		TransmitNL: begin
			enabled_tx = 1'b1;
			if(bus_cycle_tx_next == 1'b1) begin
				enabled_tx = 1'b0;
				next_state = ReceiveData;
			end
		end
	endcase
end


assign char_cur =
	state == TransmitSpace ? " " :
	state == TransmitCR ? "\r" :
	state == TransmitNL ? "\n" :
	state == TransmitData ? char_tx :
	state == TransmitBit ? (char_tx[BITS - bit_ctr - 1] == 1'b1 ? "1" : "0") :
	" ";
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// leds
// ----------------------------------------------------------------------------
assign led[0] = ~slow_clk;
assign led[1] = ~rst;
assign led[2] = ~toggled;
assign led[5:3] = 3'b111;
// ----------------------------------------------------------------------------


endmodule
