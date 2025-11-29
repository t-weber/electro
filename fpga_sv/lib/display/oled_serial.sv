/**
 * serial monochrome oled display
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 19-may-2024
 * @license see 'LICENSE' file
 *
 * references:
 *   - [oled] https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 *   - https://www.instructables.com/Getting-Started-With-OLED-Displays/
 *   - https://github.com/sipeed/TangNano-9K-example/blob/main/spi_lcd
 *   - https://github.com/sipeed/sipeed_wiki/blob/main/docs/hardware/en/tang/Tang-Nano-9K/examples/rgb_screen.md
 */


module oled_serial
#(
	parameter longint  MAIN_CLK        = 50_000_000,
	parameter shortint BUS_BITS        = 8,

	parameter shortint SCREEN_WIDTH    = 128,
	parameter shortint SCREEN_HEIGHT   = 64,
	parameter shortint SCREEN_PAGES    = SCREEN_HEIGHT / BUS_BITS,

	parameter shortint HCTR_BITS       = $clog2(SCREEN_WIDTH),
	parameter shortint VCTR_BITS       = $clog2(SCREEN_HEIGHT),
	parameter shortint PAGE_BITS       = $clog2(SCREEN_PAGES)
 )
(
	// clock and reset
	input wire in_clk, in_rst,

	// draw frame
	input wire in_update,

	// pixel data
	input wire [BUS_BITS - 1 : 0] in_pixels,
	output wire [HCTR_BITS - 1 : 0] out_hpix,
	output wire [VCTR_BITS - 1 : 0] out_vpix,
	output wire [PAGE_BITS - 1 : 0] out_vpage,

	// serial bus interface
	input wire in_bus_ready,
	input wire in_bus_next_word,
	output wire out_bus_enable,
	output wire [BUS_BITS - 1 : 0] out_bus_data
);


// --------------------------------------------------------------------
// wait timer register
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam longint WAIT_RESET     = 1;
	localparam longint WAIT_UPDATE    = 1;
`else
	localparam longint WAIT_RESET     = MAIN_CLK * 20 / 1000;  // 20 ms
	localparam longint WAIT_UPDATE    = MAIN_CLK * 50 / 1000;  // 50 ms, 20 Hz
`endif

logic [$clog2(WAIT_UPDATE /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// init data
// --------------------------------------------------------------------
localparam [3 : 0] clock_freq       = 4'd15;
localparam [3 : 0] clock_div        = 4'd0;
localparam [3 : 0] pixel_set_time   = 4'd2;
localparam [3 : 0] pixel_unset_time = 4'd2;
localparam [0 : 0] invert_h         = 1'b1;
localparam [0 : 0] invert_v         = 1'b1;
localparam [5 : 0] h_offs           = 6'd0;
localparam [7 : 0] v_offs           = 8'd0;
localparam [7 : 0] contrast         = 8'hff;
localparam [0 : 0] invert_disp      = 1'b0;

localparam [7 : 0] cmd_nocont       = 8'h80;
localparam [7 : 0] cmd_cont         = 8'h00;
localparam [7 : 0] cmd_data         = 8'h40;


// init sequence, see [oled], p. 64
localparam INIT_BYTES = 37;
logic [0 : INIT_BYTES - 1][BUS_BITS - 1 : 0] init_cmds;
assign init_cmds =
{
	// display off, [oled], p. 28
	/*  1 */ cmd_nocont, 8'ha5,
	/*  2 */ cmd_nocont, 8'hae,

	// set clock, [oled], p. 32
	/*  3 */ cmd_cont, 8'hd5, { clock_freq, clock_div },
	/*  4 */ cmd_cont, 8'hd9, { pixel_set_time, pixel_unset_time },

	// set multiplexer, [oled], p. 31
	/*  5 */ cmd_cont, 8'ha8, 8'(SCREEN_HEIGHT - 1),

	// address mode, [oled], p. 30
	/*  6 */ cmd_cont, 8'h20, 8'h00,

	// direction, [oled], p. 31
	/*  7 */ cmd_nocont, 8'ha0 | invert_h,
	/*  8 */ cmd_nocont, 8'hc0 | (invert_v << 3),

	// screen offsets, [oled], p. 31
	/*  9 */ cmd_nocont, 8'b0100_0000 | h_offs,
	/* 10 */ cmd_cont, 8'hd3, v_offs,

	// contrast, [oled], p. 28
	/* 11 */ cmd_cont, 8'h81, contrast,

	// inverted display, [oled], p. 28
	/* 12 */ cmd_nocont, 8'ha6 | invert_disp,

	// capacitor, [oled], p. 62
	/* 13 */ cmd_cont, 8'h8d, 8'b0001_0100,

	// display on, [oled], p. 28
	/* 14 */ cmd_nocont, 8'haf,
	/* 15 */ cmd_nocont, 8'ha4
};

// init command byte counter
reg [$clog2(INIT_BYTES) : 0] init_ctr = 0, next_init_ctr = 0;


// data transmission sequence
localparam DATA_BYTES = 8;
logic [0 : DATA_BYTES - 1][BUS_BITS - 1 : 0] data_cmds;
assign data_cmds =
{
	// addresses, [oled], pp. 35 - 36
	/* 1 */ cmd_cont, 8'h21, 8'h00, 8'(SCREEN_WIDTH - 1'b1),
	/* 2 */ cmd_cont, 8'h22, 8'h00, 8'(SCREEN_PAGES - 1'b1)
};

// init command byte counter
reg [$clog2(DATA_BYTES) : 0] data_ctr = 0, next_data_ctr = 0;
// --------------------------------------------------------------------


// pixel and page counters
reg [HCTR_BITS - 1 : 0] x_ctr = 0, next_x_ctr = 0;
reg [PAGE_BITS - 1 : 0] y_ctr = 0, next_y_ctr = 0;


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
assign out_hpix = x_ctr;
assign out_vpix = VCTR_BITS'(y_ctr * BUS_BITS);
assign out_vpage = y_ctr;

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
	WriteDataCmd, WriteData, NextData
} t_state;

t_state state = Reset, next_state = Reset;


// state flip-flops
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		state <= Reset;

		init_ctr <= 1'b0;
		data_ctr <= 1'b0;
		x_ctr <= 1'b0;
		y_ctr <= 1'b0;

		// timer register
		wait_ctr <= 1'b0;

		last_byte_finished <= 1'b0;
	end

	// clock
	else begin
		state <= next_state;

		init_ctr <= next_init_ctr;
		data_ctr <= next_data_ctr;
		x_ctr <= next_x_ctr;
		y_ctr <= next_y_ctr;

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
	next_x_ctr = x_ctr;
	next_y_ctr = y_ctr;

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
				bus_enable = 1'b1;
				next_init_ctr = $size(init_ctr)'(init_ctr + 1'b1);
				next_state = WriteInit;
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
				if(in_bus_ready == 1'b1)
					next_state = WriteDataCmd;
			end else begin
				bus_data = data_cmds[data_ctr];
				bus_enable = 1'b1;
				next_data_ctr = $size(data_ctr)'(data_ctr + 1'b1);
				next_state = WriteDataInit;
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write start command for data
		WriteDataCmd: begin
			bus_data = cmd_cont | cmd_data;
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = WriteData;
		end

		// write pixel data
		WriteData: begin
			bus_data = in_pixels;
			bus_enable = 1'b1;

			if(bus_cycle == 1'b1)
				next_state = NextData;
		end

		// next pixel
		NextData: begin
			bus_data = in_pixels;

			if(y_ctr + 1 == SCREEN_PAGES) begin
				// at last line
				if(x_ctr + 1 == SCREEN_WIDTH) begin
					if(in_bus_ready == 1'b1) begin
						// all finished
						next_x_ctr = 1'b0;
						next_y_ctr = 1'b0;
						next_state = WaitUpdate;
					end
				end else begin
					bus_enable = 1'b1;
					next_x_ctr = $size(x_ctr)'(x_ctr + 1'b1);
					next_state = WriteData;
				end
			end else begin
				// before last line
				bus_enable = 1'b1;
				if(x_ctr + 1 == SCREEN_WIDTH) begin
					// at last column
					next_x_ctr = 1'b0;
					next_y_ctr = $size(y_ctr)'(y_ctr + 1'b1);
					next_state = WriteData;
				end else begin
					next_x_ctr = $size(x_ctr)'(x_ctr + 1'b1);
					next_state = WriteData;
				end
			end
		end
		// ----------------------------------------------------
	endcase

`ifdef __IN_SIMULATION__
	$display("*** oled_serial: %s, x=%d, y=%d, init=%d, dat=%x. ***",
		state.name(), x_ctr, y_ctr, init_ctr, init_cmds[init_ctr]);
`endif

end
// --------------------------------------------------------------------

endmodule
