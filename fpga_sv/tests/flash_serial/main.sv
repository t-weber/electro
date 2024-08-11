/**
 * reads a flash memory and sends the results to the serial console
 *   (test: screen /dev/tty.usbserial-142101 115200)
 * @author Tobias Weber
 * @date 10-august-2024
 * @license see 'LICENSE' file
 */

`default_nettype none  // no implicit declarations


module flash_serial_mod
(
	// main clock
	input wire clk27,

	// serial interface
	output wire serial_tx,

	// flash interface,
	output wire flash_clk,
	output wire flash_sel,
	output wire flash_out,
	input wire flash_in,

	// keys and leds
	input wire [1:0] key,
	output wire [5:0] led
);


localparam MAIN_CLK   = 27_000_000;
localparam FLASH_CLK  = 10_000_000;
localparam SERIAL_CLK = 115_200;

localparam BITS       = 8;
localparam ADDR_WORDS = 3;


localparam WAIT_DELAY = MAIN_CLK/1000*250;  // 250 ms
logic [$clog2(WAIT_DELAY) : 0] wait_ctr = 1'b0;


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
logic [BITS - 1 : 0] serial_char_tx, next_serial_char_tx = 0;
wire [BITS - 1 : 0] serial_char_cur;

logic serial_enabled_tx;
logic serial_ready_tx;

logic serial_word_finished_tx, last_serial_word_finished_tx = 1'b0;
wire serial_bus_cycle_tx_next = serial_word_finished_tx && ~last_serial_word_finished_tx;

logic [$clog2(BITS) : 0] serial_bit_ctr = 0, next_serial_bit_ctr = 0;


// instantiate serial transmitter
serial_async_tx #(
	.BITS(BITS), .LOWBIT_FIRST(1'b1),
	.MAIN_CLK_HZ(MAIN_CLK),
	.SERIAL_CLK_HZ(SERIAL_CLK)
)
serial_tx_mod(
	.in_clk(clk27), .in_rst(rst),
	.in_enable(serial_enabled_tx), .out_ready(serial_ready_tx),
	.in_parallel(serial_char_cur), .out_serial(serial_tx),
	//.out_next_word(serial_word_finished_tx)
	.out_word_finished(serial_word_finished_tx)
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// flash interface
// ----------------------------------------------------------------------------
logic flash_enabled = 1'b0, flash_read = 1'b1;
logic [BITS - 1 : 0] flash_rx, flash_tx = BITS'(1'b0);
logic [BITS*ADDR_WORDS - 1 : 0] flash_addr, next_flash_addr;
logic [BITS*ADDR_WORDS - 1 : 0] flash_word_ctr;

logic flash_word_rdy, last_flash_word_rdy = 1'b0;
wire flash_bus_cycle = ~flash_word_rdy && last_flash_word_rdy;
wire flash_bus_cycle_next = flash_word_rdy && ~last_flash_word_rdy;


// instantiate flash module
flash_serial #(
	.WORD_BITS(BITS), .ADDRESS_WORDS(ADDR_WORDS),
	.MAIN_CLK(MAIN_CLK), .SERIAL_CLK(FLASH_CLK)
)
flash_mod(
	.in_clk(clk27),                  // main clock
	.in_rst(rst),                    // reset
	.in_enable(flash_enabled),       // command enable
	.in_read(flash_read),            // read or write mode
	.in_addr(flash_addr),            // address to read from
	.in_data(flash_tx),              // input data
	.out_data(flash_rx),             // output data
	.out_word_ctr(flash_word_ctr),   // currently read word index
	.out_word_ready(flash_word_rdy), // finished reading or writing a word

	// interface with flash memory pins
	.out_flash_rst(), .out_flash_clk(flash_clk),
	.out_flash_select(flash_sel),
	.out_flash_data(flash_out),
	.in_flash_data(flash_in)
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// states
// ----------------------------------------------------------------------------
typedef enum
{
	Start, WriteFlashData,
	WaitBeforeRead, ReadFlashData,
	TransmitSerialData, TransmitSerialBit,
	TransmitSerialSpace, TransmitSerialCR, TransmitSerialNL,
} t_state;
t_state state = Start, next_state = Start;


// state flip-flops
always_ff@(posedge clk27, posedge rst) begin
	// reset
	if(rst == 1'b1) begin
		state <= Start;

		serial_char_tx <= 0;
		last_serial_word_finished_tx <= 1'b0;
		serial_bit_ctr <= 0;

		flash_addr <= 1'b0;
		last_flash_word_rdy <= 1'b0;

		wait_ctr <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;

		serial_char_tx <= next_serial_char_tx;
		last_serial_word_finished_tx <= serial_word_finished_tx;
		serial_bit_ctr <= next_serial_bit_ctr;

		flash_addr <= next_flash_addr;
		last_flash_word_rdy <= flash_word_rdy;

		if(state == WaitBeforeRead || state == Start && wait_ctr != WAIT_DELAY)
			wait_ctr <= $size(wait_ctr)'(wait_ctr + 1'b1);
		else
			wait_ctr <= $size(wait_ctr)'(1'b0);
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_serial_char_tx = serial_char_tx;
	next_serial_bit_ctr = serial_bit_ctr;
	next_flash_addr = flash_addr;

	serial_enabled_tx = 1'b0;
	flash_enabled = 1'b0;
	flash_read = 1'b1;
	flash_tx = BITS'(1'b0);

	case(state)
		Start: begin
			next_flash_addr = 1'b0;
			if(wait_ctr == WAIT_DELAY)
				next_state = WriteFlashData;
		end

		WriteFlashData: begin
			flash_enabled = 1'b1;
			flash_read = 1'b0;
			flash_tx = BITS'(8'h58);

			if(flash_bus_cycle_next == 1'b1) begin
				next_state = WaitBeforeRead;
			end
		end

		WaitBeforeRead: begin
			if(wait_ctr == WAIT_DELAY)
				next_state = ReadFlashData;
		end

		ReadFlashData: begin
			flash_enabled = 1'b1;
			if(flash_bus_cycle_next == 1'b1) begin
				next_serial_char_tx = flash_rx;
				next_state = TransmitSerialData;
				next_flash_addr <= $size(flash_addr)'(flash_addr + 1'b1);
			end
		end

		TransmitSerialData: begin
			serial_enabled_tx = 1'b1;
			if(serial_bus_cycle_tx_next == 1'b1) begin
				serial_enabled_tx = 1'b0;
				next_state = TransmitSerialSpace;
			end
		end

		TransmitSerialSpace: begin
			serial_enabled_tx = 1'b1;
			if(serial_bus_cycle_tx_next == 1'b1) begin
				serial_enabled_tx = 1'b0;
				next_serial_bit_ctr <= 0;
				next_state = TransmitSerialBit;
			end
		end

		TransmitSerialBit: begin
			serial_enabled_tx = 1'b1;
			if(serial_bus_cycle_tx_next == 1'b1) begin
				serial_enabled_tx = 1'b0;

				if(serial_bit_ctr == BITS - 1) begin
					next_state = TransmitSerialCR;
					next_serial_bit_ctr = 0;
				end else begin
					next_serial_bit_ctr = $size(serial_bit_ctr)'(
						serial_bit_ctr + 1'b1);
				end
			end
		end

		TransmitSerialCR: begin
			serial_enabled_tx = 1'b1;
			if(serial_bus_cycle_tx_next == 1'b1) begin
				serial_enabled_tx = 1'b0;
				next_state = TransmitSerialNL;
			end
		end

		TransmitSerialNL: begin
			serial_enabled_tx = 1'b1;
			if(serial_bus_cycle_tx_next == 1'b1) begin
				serial_enabled_tx = 1'b0;
				next_state = WaitBeforeRead;
			end
		end
	endcase
end


assign serial_char_cur =
	state == TransmitSerialSpace ? " " :
	state == TransmitSerialCR ? "\r" :
	state == TransmitSerialNL ? "\n" :
	state == TransmitSerialData ? serial_char_tx :
	state == TransmitSerialBit ? 
		(serial_char_tx[BITS - serial_bit_ctr - 1] == 1'b1 ? "1" : "0") :
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
