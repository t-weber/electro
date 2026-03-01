/**
 * serial 2-wire text display
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date jan-2026
 * @license see 'LICENSE' file
 *
 * references:
 *   - [hw] https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 */


module txtlcd2
#(
	parameter longint MAIN_CLK   = 50_000_000,
	parameter int BUS_BITS       = 8,
	parameter int LCD_SIZE       = 4*20,
	parameter int WAIT_UPDATE_MS = 500
 )
(
	// clock and reset
	input wire in_clk, in_rst,

	input wire in_update,

	// serial bus interface
	input wire in_bus_ready,
	input wire in_bus_next,
	output wire out_bus_enable,

	input wire [BUS_BITS - 1 : 0] in_bus_data,
	output wire [BUS_BITS - 1 : 0] out_bus_data,
	output wire [BUS_BITS - 1 : 0] out_char_ctr
);


// --------------------------------------------------------------------
// wait timer register
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam longint WAIT_RESET  = 1;
	localparam longint WAIT_INIT1  = 1;
	localparam longint WAIT_INIT2  = 1;
	localparam longint WAIT_INIT3  = 1;
	localparam longint WAIT_ENABLE = 1;
	localparam longint WAIT_CLEAR  = 1;
	localparam longint WAIT_UPDATE = 1;
`else
	localparam longint WAIT_RESET  = MAIN_CLK * 250 / 1000;  // 250 ms
	localparam longint WAIT_INIT1  = MAIN_CLK * 25 / 1000;   // 25 ms
	localparam longint WAIT_INIT2  = MAIN_CLK * 5 / 1000;    // 5 ms
	localparam longint WAIT_INIT3  = MAIN_CLK * 1 / 1000;    // 1 ms
	localparam longint WAIT_ENABLE = MAIN_CLK * 1 / 1000;    // 1 ms
	localparam longint WAIT_NIBBLE = MAIN_CLK * 1 / 1000;    // 1 ms
	localparam longint WAIT_CLEAR  = MAIN_CLK * 5 / 1000;    // 5 ms
	localparam longint WAIT_UPDATE = MAIN_CLK * WAIT_UPDATE_MS / 1000;  // def: 500 ms, 2 Hz
`endif

logic [$clog2(WAIT_UPDATE /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// initialise display, [hw], p. 12
// --------------------------------------------------------------------
localparam [BUS_BITS - 1 : 0] pin_ena        = 8'b0000_0100;
localparam [BUS_BITS - 1 : 0] pin_rs         = 8'b0000_0001;
localparam [BUS_BITS - 1 : 0] pin_led        = 8'b0000_1000;

localparam [BUS_BITS - 1 : 0] set_addr       = 8'b1000_0000;

localparam [BUS_BITS - 1 : 0] set_func       = 8'b0010_0000;
localparam [BUS_BITS - 1 : 0] func_8bit      = 8'b0001_0000;
localparam [BUS_BITS - 1 : 0] func_2line     = 8'b0000_1000;
localparam [BUS_BITS - 1 : 0] func_font      = 8'b0000_0100;

localparam [BUS_BITS - 1 : 0] set_disp       = 8'b0000_1000;
localparam [BUS_BITS - 1 : 0] disp_on        = 8'b0000_0100;
localparam [BUS_BITS - 1 : 0] disp_linecaret = 8'b0000_0010;
localparam [BUS_BITS - 1 : 0] disp_boxcaret  = 8'b0000_0001;

localparam [BUS_BITS - 1 : 0] set_caret      = 8'b0000_0100;
localparam [BUS_BITS - 1 : 0] caret_inc      = 8'b0000_0010;
localparam [BUS_BITS - 1 : 0] caret_shift    = 8'b0000_0001;

localparam [BUS_BITS - 1 : 0] set_clear      = 8'b0000_0001;
localparam [BUS_BITS - 1 : 0] set_return     = 8'b0000_0010;

// init sequence
localparam int INIT_BYTES = 14*2;
logic [0 : INIT_BYTES - 1][BUS_BITS - 1 : 0] init_cmds;
assign init_cmds =
{
	set_func | func_8bit | pin_led | pin_ena,
	set_func | func_8bit | pin_led,
	set_func | func_8bit | pin_led | pin_ena,
	set_func | func_8bit | pin_led,
	set_func | func_8bit | pin_led | pin_ena,
	set_func | func_8bit | pin_led,
	set_func | pin_led | pin_ena,   // to 4 bit mode
	set_func | pin_led,

	// send high nibble and low nibble individually from here on

	// set lines
	(set_func & 8'hf0) | pin_led | pin_ena,
	(set_func & 8'hf0) | pin_led,
	BUS_BITS'((set_func & 8'h0f | func_2line) << 4) | pin_led | pin_ena,
	BUS_BITS'((set_func & 8'h0f | func_2line) << 4) | pin_led,

	// turn display on
	(set_disp & 8'hf0) | pin_led | pin_ena,
	(set_disp & 8'hf0) | pin_led,
	BUS_BITS'((set_disp & 8'h0f | disp_on /*| disp_boxcaret | disp_linecaret*/) << 4) | pin_led | pin_ena,
	BUS_BITS'((set_disp & 8'h0f | disp_on /*| disp_boxcaret | disp_linecaret*/) << 4) | pin_led,

	// clear
	(set_clear & 8'hf0) | pin_led | pin_ena,
	(set_clear & 8'hf0) | pin_led,
	BUS_BITS'((set_clear & 8'h0f) << 4) | pin_led | pin_ena,
	BUS_BITS'((set_clear & 8'h0f) << 4) | pin_led,

	// return
	(set_return & 8'hf0) | pin_led | pin_ena,
	(set_return & 8'hf0) | pin_led,
	BUS_BITS'((set_return & 8'h0f) << 4) | pin_led | pin_ena,
	BUS_BITS'((set_return & 8'h0f) << 4) | pin_led,

	// caret mode
	(set_caret & 8'hf0) | pin_led | pin_ena,
	(set_caret & 8'hf0) | pin_led,
	BUS_BITS'((set_caret & 8'h0f | caret_inc) << 4) | pin_led | pin_ena,
	BUS_BITS'((set_caret & 8'h0f | caret_inc) << 4) | pin_led
};

logic [0 : INIT_BYTES - 1][$size(wait_ctr) - 1 : 0] init_wait;
assign init_wait =
{
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT1),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT2),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3),

	// set lines
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_NIBBLE),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3),

	// turn display on
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_NIBBLE),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3),

	// clear
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_NIBBLE),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3),

	// return
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_NIBBLE),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3),
	
	// set caret
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_NIBBLE),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3)
};


// init sequence before update
localparam int INIT2_BYTES = 2*2;
logic [0 : INIT2_BYTES - 1][BUS_BITS - 1 : 0] init2_cmds;
assign init2_cmds =
{
	// set address
	(set_addr & 8'hf0) | pin_led | pin_ena, (set_addr & 8'hf0) | pin_led,
	BUS_BITS'((set_addr & 8'h0f) << 4) | pin_led | pin_ena, BUS_BITS'((set_addr & 8'h0f) << 4) | pin_led
};

logic [0 : INIT2_BYTES - 1][$size(wait_ctr) - 1 : 0] init2_wait;
assign init2_wait =
{
	// set address
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_NIBBLE),
	$size(wait_ctr)'(WAIT_ENABLE), $size(wait_ctr)'(WAIT_INIT3)
};

// init command byte counter
logic [$clog2(INIT_BYTES + 1) : 0] init_ctr = 0, next_init_ctr = 0;

// data byte counter
logic [$clog2(LCD_SIZE) : 0] char_ctr = 0, next_char_ctr = 0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// serial bus interface
// --------------------------------------------------------------------
logic last_finished = 1'b0;
wire bus_cycle = in_bus_next && ~last_finished;

logic bus_enable = 1'b0;
logic [BUS_BITS - 1 : 0] bus_data = BUS_BITS'(1'b0);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// outputs
// --------------------------------------------------------------------
assign out_bus_enable = bus_enable;
assign out_bus_data = bus_data;
assign out_char_ctr = char_ctr;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// states
// --------------------------------------------------------------------
typedef enum {
	Reset,
	WriteInit, WaitInit, WriteInit2, WaitInit2,
	WaitUpdate, WaitUpdate2,
	WriteDataHigh, WriteDataHighWait, WriteDataHighEnd, WriteDataAfterHigh,
	WriteDataLow, WriteDataLowWait, WriteDataLowEnd, WriteDataAfterLow,
	NextData
} t_state;

t_state state = Reset, next_state = Reset;


// state flip-flops
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		state <= Reset;

		init_ctr <= 1'b0;
		char_ctr <= 1'b0;

		// timer register
		wait_ctr <= 1'b0;

		last_finished <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;

		init_ctr <= next_init_ctr;
		char_ctr <= next_char_ctr;

		// timer register
		if(wait_ctr == wait_ctr_max) begin
			// reset timer counter
			wait_ctr <= $size(wait_ctr)'(1'b0);
		end else begin
			// next timer counter
			wait_ctr <= $size(wait_ctr)'(wait_ctr + 1'b1);
		end

		last_finished <= in_bus_next;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_init_ctr = init_ctr;
	next_char_ctr = char_ctr;

	wait_ctr_max = 1'b0;
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

			if(bus_cycle == 1'b1) begin
				next_init_ctr = $size(init_ctr)'(init_ctr + 1'b1);
				next_state = WaitInit;
			end
		end

		WaitInit: begin
			wait_ctr_max = init_wait[init_ctr - 1];
			if(wait_ctr == wait_ctr_max) begin
				if(init_ctr == INIT_BYTES) begin
					next_state = WaitUpdate2;
					next_init_ctr = 1'b0;
				end else begin
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
			if(in_update == 1'b1) begin
				next_state = WriteInit2;
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write init commands
		WriteInit2: begin
			bus_data = init2_cmds[init_ctr];
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1) begin
				next_init_ctr = $size(init_ctr)'(init_ctr + 1'b1);
				next_state = WaitInit2;
			end
		end

		WaitInit2: begin
			wait_ctr_max = init2_wait[init_ctr - 1];
			if(wait_ctr == wait_ctr_max) begin
				if(init_ctr == INIT2_BYTES) begin
					next_init_ctr = 1'b0;
					next_state = WriteDataHigh;
				end else begin
					next_state = WriteInit2;
				end
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write high nibble of text byte
		WriteDataHigh: begin
			bus_data = in_bus_data & 8'hf0 | pin_led | pin_rs | pin_ena;
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = WriteDataHighWait;
		end

		WriteDataHighWait: begin
			wait_ctr_max = WAIT_ENABLE;
			if(wait_ctr == wait_ctr_max)
				next_state = WriteDataHighEnd;
		end

		WriteDataHighEnd: begin
			bus_data = in_bus_data & 8'hf0 | pin_led | pin_rs;
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = WriteDataAfterHigh;
		end

		WriteDataAfterHigh: begin
			wait_ctr_max = WAIT_NIBBLE;
			if(wait_ctr == wait_ctr_max)
				next_state = WriteDataLow;
		end

		// write low nibble of text byte
		WriteDataLow: begin
			bus_data = (in_bus_data & 8'h0f) << 4 | pin_led | pin_rs | pin_ena;
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = WriteDataLowWait;
		end

		WriteDataLowWait: begin
			wait_ctr_max = WAIT_ENABLE;
			if(wait_ctr == wait_ctr_max)
				next_state = WriteDataLowEnd;
		end

		WriteDataLowEnd: begin
			bus_data = (in_bus_data & 8'h0f) << 4 | pin_led | pin_rs;
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = WriteDataAfterLow;
		end

		WriteDataAfterLow: begin
			wait_ctr_max = WAIT_NIBBLE;
			if(wait_ctr == wait_ctr_max)
				next_state = NextData;
		end

		// next byte
		NextData: begin
			if(char_ctr == LCD_SIZE - 1) begin
				// at last segment
				if(in_bus_ready == 1'b1) begin
					// all finished
					next_char_ctr = 1'b0;
					next_state = WaitUpdate;
				end
			end else begin
				next_char_ctr = $size(char_ctr)'(char_ctr + 1'b1);
				next_state = WriteDataHigh;
			end
		end
		// ----------------------------------------------------

	endcase

`ifdef __IN_SIMULATION__
	$display("*** txtlcd2: %s, seg=%d, init=%d, dat=%x, delay=%d. ***",
		state.name(), char_ctr, init_ctr, init_cmds[init_ctr], init_wait[init_ctr]);
`endif

end
// --------------------------------------------------------------------

endmodule
