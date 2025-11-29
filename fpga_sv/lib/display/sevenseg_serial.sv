/**
 * serial seven segment display
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 18-oct-2025
 * @license see 'LICENSE' file
 *
 * references:
 *   - https://www.puntoflotante.net/TM1637-7-SEGMENT-DISPLAY-FOR-MICROCONTROLLER.htm
 */


module sevenseg_serial
#(
	parameter longint MAIN_CLK = 50_000_000,
	parameter byte BUS_BITS    = 8,
	parameter byte NUM_SEGS    = 6
 )
(
	// clock and reset
	input wire in_clk, in_rst,

	input wire in_update,
	input wire [4*NUM_SEGS - 1 : 0] in_digits,

	// serial bus interface
	input wire in_bus_ready,
	input wire in_bus_next_word,
	output wire out_bus_enable,
	output wire [BUS_BITS - 1 : 0] out_bus_data
);


// --------------------------------------------------------------------
// memory
// --------------------------------------------------------------------
reg [4*NUM_SEGS - 1 : 0] mem, next_mem;
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

	// get input data
	if(in_update == 1'b1) begin
		next_update = 1'b1;
		next_mem = in_digits;
	end
end
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// seven segment decoder module
// --------------------------------------------------------------------
logic [3 : 0] digit;
logic [6 : 0] leds;

assign digit = mem[seg_ctr*4 +: 4];


sevenseg #(
	.ZERO_IS_ON(0),
	.INVERSE_NUMBERING(1),
	.ROTATED(1)
)
sevenseg_mod(
	.in_digit(digit),
	.out_leds(leds)
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// wait timer register
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam longint WAIT_RESET  = 1;
	localparam longint WAIT_UPDATE = 1;
`else
	localparam longint WAIT_RESET  = MAIN_CLK * 100 / 1000;  // 100 ms
	localparam longint WAIT_UPDATE = MAIN_CLK * 100 / 1000;  // 100 ms, 10 Hz
`endif

logic [$clog2(WAIT_UPDATE /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// init data
// --------------------------------------------------------------------
// basic command types
localparam [3 : 0] cmd_data   = 4'b0100;
localparam [3 : 0] cmd_disp   = 4'b1000;
localparam [3 : 0] cmd_addr   = 4'b1100;

// constant (1) or incrementing (0) address
localparam [0 : 0] const_addr = 1'b1;
// led brightness
localparam [3 : 0] brightness = 4'hf;


// init sequence
localparam int INIT_BYTES = 1;
logic [0 : INIT_BYTES - 1][BUS_BITS - 1 : 0] init_cmds;
assign init_cmds =
{
	{ cmd_disp, brightness }
};

// init command byte counter
reg [$clog2(INIT_BYTES) : 0] init_ctr = 0, next_init_ctr = 0;


// data transmission sequence
localparam int DATA_BYTES = 2;
logic [0 : DATA_BYTES - 1][BUS_BITS - 1 : 0] data_cmds;
assign data_cmds =
{
	{ cmd_data, 1'b0, ~const_addr, 1'b0, 1'b0 },
	{ cmd_addr, 4'b0000 }  // start with address 0
};

// data init command byte counter
reg [$clog2(DATA_BYTES) : 0] data_ctr = 0, next_data_ctr = 0;
// data byte counter
reg [$clog2(NUM_SEGS) : 0] seg_ctr = 0, next_seg_ctr = 0;
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
	WriteDataInit, NextDataInit,
	WriteData, NextData
} t_state;

t_state state = Reset, next_state = Reset;


// state flip-flops
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		state <= Reset;

		init_ctr <= 1'b0;
		data_ctr <= 1'b0;
		seg_ctr <= 1'b0;

		// timer register
		wait_ctr <= 1'b0;

		last_byte_finished <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;

		init_ctr <= next_init_ctr;
		data_ctr <= next_data_ctr;
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
	next_data_ctr = data_ctr;
	next_seg_ctr = seg_ctr;

	wait_ctr_max = WAIT_RESET;
	bus_enable = 1'b0;
	bus_data = 0;

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
			if(init_ctr + 1 == INIT_BYTES) begin
				if(in_bus_ready == 1'b1)
					next_state = WaitUpdate;
			end else begin
				bus_data = init_cmds[init_ctr];

				// send stop signal
				//bus_enable = 1'b1;
				if(in_bus_ready == 1'b1) begin
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
				next_state = WriteDataInit;
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write data transfer commands
		WriteDataInit: begin
			bus_data = data_cmds[data_ctr];
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = NextDataInit;
		end

		NextDataInit: begin
			if(data_ctr + 1 == DATA_BYTES) begin
				// keep enabled, don't send stop signal
				bus_enable = 1'b1;
				//if(in_bus_ready == 1'b1)
					next_state = WriteData;
			end else begin
				bus_data = data_cmds[data_ctr];
				//bus_enable = 1'b1;
				if(in_bus_ready == 1'b1) begin
					next_data_ctr = $size(data_ctr)'(data_ctr + 1'b1);
					next_state = WriteDataInit;
				end
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write segment byte
		WriteData: begin
			bus_data = {1'b0, leds};
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = NextData;
		end

		// next segment byte
		NextData: begin
			bus_data = {1'b0, leds};

			if(seg_ctr + 1 == NUM_SEGS) begin
				// at last segment
				if(in_bus_ready == 1'b1) begin
					// all finished
					next_seg_ctr = 1'b0;
					next_state = WaitUpdate;
				end
			end else begin
				next_seg_ctr = $size(seg_ctr)'(seg_ctr + 1'b1);
				next_state = WriteData;
				bus_enable = 1'b1;
			end
		end
		// ----------------------------------------------------

	endcase

`ifdef __IN_SIMULATION__
	$display("*** sevenseg_serial: %s, seg=%d, init=%d, dat=%x. ***",
		state.name(), seg_ctr, init_ctr, init_cmds[init_ctr]);
`endif

end
// --------------------------------------------------------------------

endmodule
