/**
 * serial seven segment display test
 * @author Tobias Weber
 * @date 18-oct-2025
 * @license see 'LICENSE' file
 */


module sevenseg_test
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	output [2:0] led,

	// red leds
	output [7:0] ledr,

	// seven segment leds
	inout sevenseg_clk,
	inout sevenseg_dat
);


localparam MAIN_CLK      = 27_000_000;
localparam SERIAL_CLK    =     10_000;
localparam SLOW_CLK      =          2;

localparam SERIAL_BITS   = 8;


// ----------------------------------------------------------------------------
// keys
// ----------------------------------------------------------------------------
wire rst, stop_update;

debounce_switch debounce_key0(.in_clk(clk27), .in_rst(1'b0),
	.in_signal(~key[0]), .out_debounced(rst));

debounce_button debounce_key1(.in_clk(clk27), .in_rst(rst),
	.in_signal(~key[1]), .out_toggled(stop_update), .out_debounced());
// ----------------------------------------------------------------------------


// --------------------------------------------------------------------
// seven segment serial bus
// --------------------------------------------------------------------
wire serial_enable, serial_ready, serial_error;
wire [SERIAL_BITS - 1 : 0] serial_in_parallel;
wire serial_next_word;

// instantiate serial module
serial_2wire #(
	.BITS(SERIAL_BITS), .LOWBIT_FIRST(1), .TRANSMIT_ADDR(0),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
`ifdef __IN_SIMULATION__
	.IGNORE_ERROR(1'b1)
`else
	.IGNORE_ERROR(1'b0)
`endif
)
serial_mod(
	.in_clk(clk27), .in_rst(rst), .out_err(serial_error),
	.in_enable(serial_enable), .in_write(1'b1), .out_ready(serial_ready),
	.in_addr_write(1'b0), .in_addr_read(1'b0),
	.inout_serial_clk(sevenseg_clk), .inout_serial(sevenseg_dat),
	.in_parallel(serial_in_parallel), .out_parallel(),
	.out_next_word(serial_next_word)
);
// --------------------------------------------------------------------


// ----------------------------------------------------------------------------
// serial interface
// ----------------------------------------------------------------------------
sevenseg_serial #(
	.MAIN_CLK(MAIN_CLK),
	.BUS_BITS(SERIAL_BITS),
	.NUM_SEGS(4))
sevenseg_mod (.in_clk(clk27), .in_rst(rst),
	.in_update(~stop_update), .in_digits(ctr),
	.in_bus_ready(serial_ready), .in_bus_next_word(serial_next_word),
	.out_bus_enable(serial_enable), .out_bus_data(serial_in_parallel)
);
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// slow clock
// ----------------------------------------------------------------------------
wire slow_clk;

clkgen #(.MAIN_CLK_HZ(MAIN_CLK), .CLK_HZ(SLOW_CLK))
clk_slow (.in_clk(clk27), .in_rst(rst), .out_clk(slow_clk));
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// counter
// ----------------------------------------------------------------------------
reg [15 : 0] ctr;

always_ff@(posedge slow_clk, posedge rst) begin
	if(rst == 1'b1)
		ctr <= 1'b0;
	else
		ctr <= ctr + 1'b1;
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// outputs
// ----------------------------------------------------------------------------
//assign ledr = { $size(ledr) { slow_clk } };
assign ledr[0] = ~stop_update;
assign ledr[7:1] = 1'b0;

assign led[0] = serial_error ? ~slow_clk : 1'b1;
assign led[1] = 1'b1;
assign led[2] = ~serial_ready;
// ----------------------------------------------------------------------------


endmodule
