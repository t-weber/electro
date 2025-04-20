/**
 * serial communication
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


localparam MAIN_CLK   = 27_000_000;
localparam SERIAL_CLK =    115_200;

localparam BITS = 8;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
logic rst, toggled, ready;

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
// data
localparam NUM_BYTES = 4;
logic [0 : NUM_BYTES-1] [BITS-1 : 0] data_tosend =
{
	"T", "e", "s", "t"
};

// data byte counter
logic [$clog2(NUM_BYTES) : 0] byte_ctr = 0, next_byte_ctr = 0;

logic [BITS - 1 : 0] cur_char;
logic enabled;

logic word_finished, last_word_finished = 1'b0;
wire bus_cycle = word_finished && ~last_word_finished;

serial_async_tx #(
	.BITS(BITS), .LOWBIT_FIRST(1),
	.MAIN_CLK_HZ(MAIN_CLK),
	.SERIAL_CLK_HZ(SERIAL_CLK)
)
serial_mod(
	.in_clk(clk27), .in_rst(1'b0),
	.in_enable(enabled), .out_ready(ready),
	.in_parallel(cur_char), .out_serial(serial_tx),
	.out_next_word(word_finished)
);

typedef enum bit [2 : 0]
{
	Reset, Idle,
	WriteData, NextData
} t_state;
t_state state = Reset, next_state = Reset;


// state flip-flops
always_ff@(posedge clk27, posedge rst) begin
	// reset
	if(rst == 1'b1) begin
		state <= Reset;
		byte_ctr <= 0;
		last_word_finished <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;
		byte_ctr <= next_byte_ctr;
		last_word_finished <= word_finished;
        end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_byte_ctr = byte_ctr;

	enabled = 1'b0;
	cur_char = 0;

	unique case(state)
		Reset: begin
			next_state = WriteData;
		end

		WriteData: begin
			enabled = 1'b1;
			cur_char = data_tosend[byte_ctr];

			if(bus_cycle == 1'b1)
				next_state = NextData;
		end

		NextData: begin
			enabled = 1'b1;

			//if(ready == 1'b1) begin
				if(byte_ctr + 1 == NUM_BYTES) begin
					next_state = Idle;
				end else begin
					next_byte_ctr = byte_ctr + 1;
					next_state = WriteData;
				end;
			//end;
		end

		Idle: begin
		end
	endcase
end

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
