/**
 * serial seven segment display test
 * @author Tobias Weber
 * @date 18-oct-2025
 * @license see 'LICENSE' file
 */


module ledmatrix_test
(
	// main clock
	input clk27,

	// keys and leds
	input  [1:0] key,
	output [5:0] led,

	// led matrix
	output mat_dat,
	output mat_sel,
	output mat_clk
);


localparam longint MAIN_CLK   = 27_000_000;
localparam longint SERIAL_CLK =  1_000_000;
localparam longint SLOW_CLK   =         10;

localparam byte SERIAL_BITS   = 16;


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
// led matrix serial bus
// --------------------------------------------------------------------
wire serial_enable, serial_ready;
wire [SERIAL_BITS - 1 : 0] serial_in_parallel;
wire serial_next_word;

// instantiate serial module
serial_tx #(
	.BITS(SERIAL_BITS), .LOWBIT_FIRST(1'b0), .FALLING_EDGE(1'b0),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
	.SERIAL_CLK_INACTIVE(1'b0), .SERIAL_DATA_INACTIVE(1'b0)
)
serial_mod(
	.in_clk(clk27), .in_rst(rst),
	.in_enable(serial_enable), .out_ready(serial_ready),
	.out_clk(mat_clk), .out_serial(mat_dat),
	.in_parallel(serial_in_parallel), .out_next_word(serial_next_word)
);
// --------------------------------------------------------------------


// ----------------------------------------------------------------------------
// serial interface
// ----------------------------------------------------------------------------
ledmatrix #(.MAIN_CLK(MAIN_CLK), .BUS_BITS(SERIAL_BITS),
	.NUM_SEGS(8), .LEDS_PER_SEG(8), .TRANSPOSE(1'b1))
ledmatrix_mod (.in_clk(clk27), .in_rst(rst),
	.in_update(~stop_update), .in_bits(ctr /*64'h0807060504030201*/),
	.in_bus_ready(serial_ready), .in_bus_next_word(serial_next_word),
	.out_bus_enable(serial_enable), .out_bus_data(serial_in_parallel),
	.out_seg_enable(mat_sel)
);

//assign mat_sel = serial_enable;
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
reg [8*8 - 1 : 0] ctr;

always_ff@(posedge slow_clk, posedge rst) begin
	if(rst == 1'b1)
		//ctr <= 1'b0;
		ctr <= 1'b1;
	else
		//ctr <= ctr + 1'b1;
		ctr <= (ctr == 1'b1 << 63 ? 1'b1 : ctr << 1'b1);
end
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// status outputs
// ----------------------------------------------------------------------------
assign led[0] = ~serial_ready;
assign led[1] = ~stop_update;
assign led[5:2] = 4'b1111;
// ----------------------------------------------------------------------------


endmodule
