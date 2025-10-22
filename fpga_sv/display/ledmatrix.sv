/**
 * led matrix
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 19-oct-2025
 * @license see 'LICENSE' file
 *
 * references:
 *   - [hw] https://www.analog.com/en/products/max7219.html
 */

// use seven segment decoder (otherwise raw led matrix)
//`define LEDMAT_SEVENSEG


module ledmatrix
#(
	parameter MAIN_CLK     = 50_000_000,
	parameter BUS_BITS     = 16,

	parameter NUM_SEGS     = 8,
	parameter LEDS_PER_SEG = 8,

	// transpose pixel matrix (or reverse segment order)
	parameter TRANSPOSE    = 1'b0
 )
(
	// clock and reset
	input wire in_clk, in_rst,
	input wire in_update,

`ifdef LEDMAT_SEVENSEG
	// input digits for seven segment displays
	input wire [4*NUM_SEGS - 1 : 0] in_digits,
`else
	// input pixels for led matrix
	input wire [LEDS_PER_SEG*NUM_SEGS - 1 : 0] in_bits,
`endif

	// serial bus interface
	input wire in_bus_ready,
	input wire in_bus_next_word,
	output wire out_bus_enable,
	output wire [BUS_BITS - 1 : 0] out_bus_data
);


// --------------------------------------------------------------------
// memory
// --------------------------------------------------------------------
`ifdef LEDMAT_SEVENSEG
	reg [4*NUM_SEGS - 1 : 0] mem, next_mem;
`else
	reg [LEDS_PER_SEG*NUM_SEGS - 1 : 0] mem, next_mem;
`endif

logic update, next_update;


always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		mem <= 1'b0;
		update <= 1'b1;
	end
	// clock
	else begin
		mem <= next_mem;
		update <= next_update;
	end
end


always_comb begin
	next_mem = mem;
	next_update = update;

	if(in_update == 1'b1) begin
		next_update = 1'b1;
`ifdef LEDMAT_SEVENSEG
		next_mem = in_digits;
`else
		next_mem = in_bits;
`endif
	end
end
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// decoder module or pixel assignments
// --------------------------------------------------------------------
logic [LEDS_PER_SEG - 1 : 0] leds;


`ifdef LEDMAT_SEVENSEG
	logic [3 : 0] digit;

	generate
		if(TRANSPOSE == 1'b1)
			assign digit = mem[(seg_ctr - 1'b1)*4 +: 4];
		else
			assign digit = mem[(NUM_SEGS - seg_ctr)*4 +: 4];
	endgenerate

	assign leds[7] = 1'b0;

	// seven segment decoder
	sevenseg #(.ZERO_IS_ON(0), .INVERSE_NUMBERING(1'b0), .ROTATED(~TRANSPOSE))
	sevenseg_mod(.in_digit(digit), .out_leds(leds[6 : 0]));

`else

	// pixel matrix assignments
	generate
		if(TRANSPOSE == 1'b0)
			assign leds = mem[(seg_ctr - 1'b1)*LEDS_PER_SEG +: LEDS_PER_SEG];
		else
			assign leds = {
				mem[7*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)],
				mem[6*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)],
				mem[5*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)],
				mem[4*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)],
				mem[3*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)],
				mem[2*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)],
				mem[1*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)],
				mem[0*LEDS_PER_SEG + (NUM_SEGS - seg_ctr)]
			};
	endgenerate
`endif
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// wait timer register
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam WAIT_RESET  = 1;
	localparam WAIT_UPDATE = 1;
`else
	localparam WAIT_RESET  = MAIN_CLK/1000*100;  // 100 ms
	localparam WAIT_UPDATE = MAIN_CLK/1000*50;   // 50 ms, 20 Hz
`endif

logic [$clog2(WAIT_UPDATE /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// init data
// --------------------------------------------------------------------
// basic command types, [hw, p. 7]
localparam [7 : 0] cmd_decode     = 8'b0000_1001;
localparam [7 : 0] cmd_brightness = 8'b0000_1010;
localparam [7 : 0] cmd_limit      = 8'b0000_1011;
localparam [7 : 0] cmd_power      = 8'b0000_1100;
localparam [7 : 0] cmd_test       = 8'b0000_1111;


// init sequence, [hw, pp. 7 - 10]
localparam INIT_WORDS = 5;
logic [0 : INIT_WORDS - 1][BUS_BITS - 1 : 0] init_cmds;
assign init_cmds =
{
	{ cmd_power,      8'b0000_0001 },
	{ cmd_decode,     8'b0000_0000 },
	{ cmd_brightness, 8'b0000_1111 },
	{ cmd_limit,      8'(NUM_SEGS - 1'b1) },
	{ cmd_test,       8'b0000_0000 }/*,
	{ 8'b0000_0001,   8'b0000_0001 },
	{ 8'b0000_0010,   8'b0000_0011 },
	{ 8'b0000_0011,   8'b0000_0111 },
	{ 8'b0000_0100,   8'b0000_1111 },
	{ 8'b0000_0101,   8'b0001_1111 },
	{ 8'b0000_0110,   8'b0011_1111 },
	{ 8'b0000_0111,   8'b0111_1111 },
	{ 8'b0000_1000,   8'b1111_1111 }*/
};

// init command byte counter
reg [$clog2(INIT_WORDS) : 0] init_ctr = 0, next_init_ctr = 0;


// data byte counter
reg [$clog2(NUM_SEGS + 1'b1) : 0] seg_ctr = 1'b1, next_seg_ctr = 1'b1;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// serial bus interface
// --------------------------------------------------------------------
logic last_byte_finished = 1'b0;
wire bus_cycle = in_bus_next_word && ~last_byte_finished;
//wire bus_cycle_next = ~in_bus_next_word && last_byte_finished;

logic bus_enable = 1'b0;
logic [BUS_BITS - 1 : 0] bus_data = BUS_BITS'(1'b0);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// outputs
// --------------------------------------------------------------------
assign out_bus_enable = bus_enable;
assign out_bus_data = bus_data;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// states
// --------------------------------------------------------------------
typedef enum {
	Reset,
	WriteInit, NextInit,
	WaitUpdate, WaitUpdate2,
	WriteData, NextData
} t_state;

t_state state = Reset, next_state = Reset;


// state flip-flops
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		state <= Reset;

		init_ctr <= 1'b0;
		seg_ctr <= 1'b1;

		// timer register
		wait_ctr <= 1'b0;

		last_byte_finished <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;

		init_ctr <= next_init_ctr;
		seg_ctr <= next_seg_ctr;

		// timer register
		if(wait_ctr == wait_ctr_max) begin
			// reset timer counter
			wait_ctr <= $size(wait_ctr)'(1'b0);
		end else begin
			// next timer counter
			wait_ctr <= $size(wait_ctr)'(wait_ctr + 1'b1);
		end

		last_byte_finished <= in_bus_next_word;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_init_ctr = init_ctr;
	next_seg_ctr = seg_ctr;

	wait_ctr_max = WAIT_RESET;
	bus_enable = 1'b0;
	bus_data = 1'b0;

	unique case(state)
		Reset: begin
			wait_ctr_max = WAIT_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = WriteInit;
		end


		// ----------------------------------------------------
		// write init commands
		WriteInit: begin
			bus_data = init_cmds[init_ctr];
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = NextInit;
		end

		NextInit: begin
			bus_data = init_cmds[init_ctr];
			if(in_bus_ready == 1'b1) begin
				if(init_ctr + 1'b1 == INIT_WORDS) begin
					next_state = WaitUpdate;
				end else begin
					next_init_ctr = $size(init_ctr)'(init_ctr + 1'b1);
					next_state = WriteInit;
				end
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// wait for update timer and signal
		WaitUpdate: begin
			wait_ctr_max = WAIT_UPDATE;
			if(wait_ctr == wait_ctr_max)
				next_state = WaitUpdate2;
		end

		WaitUpdate2: begin
			if(update == 1'b1) begin
				next_state = WriteData;
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write segment byte
		WriteData: begin
			bus_data = { (BUS_BITS/2)'(seg_ctr), leds };
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = NextData;
		end

		// next segment byte
		NextData: begin
			bus_data = { (BUS_BITS/2)'(seg_ctr), leds };
			if(in_bus_ready == 1'b1) begin
				if(seg_ctr == NUM_SEGS) begin
					// at last segment
					next_seg_ctr = 1'b1;
					next_state = WaitUpdate;
				end else begin
					next_seg_ctr = $size(seg_ctr)'(seg_ctr + 1'b1);
					next_state = WriteData;
				end
			end
		end
		// ----------------------------------------------------

	endcase

`ifdef __IN_SIMULATION__
	$display("*** ledmatrix: %s, seg=%d, init=%d, dat=%x. ***",
		state.name(), seg_ctr, init_ctr, init_cmds[init_ctr]);
`endif

end
// --------------------------------------------------------------------

endmodule
