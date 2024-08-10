/**
 * display with serial interface
 * @author Tobias Weber
 * @date 4-may-2024
 * @license see 'LICENSE' file
 *
 * references:
 *   - [lcd]  https://www.waveshare.com/wiki/1.14inch_LCD_Module
 *   - [ctrl] https://www.waveshare.com/wiki/1.14inch_LCD_Module -> Resources -> Datasheet
 *   - https://github.com/sipeed/TangNano-9K-example/blob/main/spi_lcd
 *   - https://github.com/sipeed/sipeed_wiki/blob/main/docs/hardware/en/tang/Tang-Nano-9K/examples/rgb_screen.md
 */


module video_serial
#(
	parameter SERIAL_BITS     = 8,
	parameter PIXEL_BITS      = 16,
	parameter RED_BITS        = 5,
	parameter GREEN_BITS      = 6,
	parameter BLUE_BITS       = 5,

	parameter SCREEN_HOFFS    = 0,
	parameter SCREEN_VOFFS    = 0,
	parameter SCREEN_WIDTH    = 128,
	parameter SCREEN_HEIGHT   = 64,

	parameter SCREEN_HINV     = 1'b1,
	parameter SCREEN_VINV     = 1'b0,
	parameter SCREEN_HVINV    = 1'b1,
	parameter SCREEN_RGBINV   = 1'b0,

	parameter MAIN_CLK        = 50_000_000,
	parameter SERIAL_CLK      = 10_000_000,

	parameter HCTR_BITS       = $clog2(SCREEN_WIDTH),
	parameter VCTR_BITS       = $clog2(SCREEN_HEIGHT),

	parameter USE_TESTPATTERN = 1'b1
 )
(
	// clock and reset
	input wire in_clk, in_rst,

	// show test pattern?
	input wire in_testpattern,

	// draw frame
	input wire in_update,

	// pixel data
	input wire [PIXEL_BITS - 1 : 0] in_pixel,
	output wire [HCTR_BITS - 1 : 0] out_hpix,
	output wire [VCTR_BITS - 1 : 0] out_vpix,

	// serial video interface
	output wire out_vid_rst,         // reset
	output wire out_vid_select,      // chip select
	output wire out_vid_cmd,         // 0: command, 1: data
	output wire out_vid_serial_clk,  // serial clock
	output wire out_vid_serial       // serial data
);


// --------------------------------------------------------------------
// wait timer register
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam WAIT_RESET       = 1;
	localparam WAIT_AFTER_RESET = 1;
	localparam WAIT_UPDATE      = 1;
`else
	localparam WAIT_RESET       = MAIN_CLK/1000/1000*50; // >=10 us, see [ctrl, p. 48]
	localparam WAIT_AFTER_RESET = MAIN_CLK/1000*150;     // >129 ms, see [ctrl, p. 49]
	localparam WAIT_UPDATE      = MAIN_CLK/1000*50;      // 50 ms, 20 Hz
`endif

logic [$clog2(WAIT_AFTER_RESET /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// init data
// --------------------------------------------------------------------
localparam [15 : 0] x_start = 16'(SCREEN_HOFFS), x_end = 16'(x_start + SCREEN_WIDTH - 1'b1);
localparam [15 : 0] y_start = 16'(SCREEN_VOFFS), y_end = 16'(y_start + SCREEN_HEIGHT - 1'b1);

// start display [ctrl, pp. 156ff]
localparam INIT_BYTES = 17;

logic [0 : INIT_BYTES - 1][SERIAL_BITS - 1 : 0] init_data;
assign init_data =
{
	//8'h01,  // reset [ctrl, p. 163]
	8'h11,  // enable [ctrl, p. 184]
	//8'h20,  // no colour inversion [ctrl, p. 188]
	8'h21,  // colour inversion [ctrl, p. 190]
	8'h29,  // output data ram [ctrl, p. 196]
	8'h2a, x_start[15:8], x_start[7:0], x_end[15:8], x_end[7:0],  // set width [ctrl, p. 198]
	8'h2b, y_start[15:8], y_start[7:0], y_end[15:8], y_end[7:0],  // set height [ctrl, p. 200]
	8'h36, { SCREEN_HINV, SCREEN_VINV, SCREEN_HVINV, 1'b0, SCREEN_RGBINV, 3'b000 },  // data ram access [ctrl, p. 215]
	8'h3a, 8'b0101_0101  // 16 bit pixel format [ctrl, p. 224]
};

logic [0 : INIT_BYTES - 1] init_cmd;
assign init_cmd =
{
	//1'b0,  // reset [ctrl, p. 163]
	1'b0,  // enable [ctrl, p. 184]
	1'b0,  // colour inversion [ctrl, p. 190]
	1'b0,  // output data ram [ctrl, p. 196]
	1'b0, 1'b1, 1'b1, 1'b1, 1'b1,  // set width [ctrl, p. 198]
	1'b0, 1'b1, 1'b1, 1'b1, 1'b1,  // set height [ctrl, p. 200]
	1'b0, 1'b1,  // data ram access [ctrl, p. 215]
	1'b0, 1'b1   // pixel format [ctrl, p. 224]
};

// init data byte counter
reg [$clog2(INIT_BYTES) : 0] init_ctr = 0, next_init_ctr = 0;
// --------------------------------------------------------------------


// pixel counters
reg [HCTR_BITS - 1 : 0] x_ctr = 0, next_x_ctr = 0;
reg [VCTR_BITS - 1 : 0] y_ctr = 0, next_y_ctr = 0;

// video interface
logic vid_rst, vid_cmd;


// --------------------------------------------------------------------
// serial interface
// --------------------------------------------------------------------
logic serial_enable, serial_ready;
logic serial, serial_clk;
logic [SERIAL_BITS-1 : 0] data;

logic byte_finished, last_byte_finished = 0;
wire bus_cycle = byte_finished && ~last_byte_finished;
//wire bus_cycle_next = ~byte_finished && last_byte_finished;

serial #(
	.BITS(SERIAL_BITS), .LOWBIT_FIRST(0),
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
	.SERIAL_CLK_INACTIVE(1), .SERIAL_DATA_INACTIVE(0),
	.KEEP_SERIAL_CLK_RUNNING(1)
)
serial_mod(
	.in_clk(in_clk), .in_rst(in_rst),
	.in_parallel(data), .in_enable(serial_enable),
	.out_serial(serial), .out_next_word(byte_finished),
	.out_ready(serial_ready), .out_clk(serial_clk),
	.in_serial(serial), .out_parallel()
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// generate test pattern
// --------------------------------------------------------------------
// test pattern values
logic [PIXEL_BITS - 1 : 0] pattern;


generate
if(USE_TESTPATTERN) begin
	testpattern
	#(
		.HPIX(SCREEN_WIDTH), .VPIX(SCREEN_HEIGHT),
		.PIXEL_BITS(PIXEL_BITS), .RED_BITS(RED_BITS),
		.GREEN_BITS(GREEN_BITS), .BLUE_BITS(BLUE_BITS),
		.HCTR_BITS(HCTR_BITS), .VCTR_BITS(VCTR_BITS)
	)
	testpattern_mod
	(
		.in_hpix(x_ctr), .in_vpix(y_ctr),
		.out_pattern(pattern)
	);
end else begin
	assign pattern = 0;
end
endgenerate
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// outputs
// --------------------------------------------------------------------
assign out_hpix = x_ctr;
assign out_vpix = y_ctr;

assign out_vid_rst = vid_rst;
assign out_vid_select = ~serial_ready;
assign out_vid_cmd = vid_cmd;
assign out_vid_serial = serial;
assign out_vid_serial_clk = serial_clk;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// states
// --------------------------------------------------------------------
typedef enum {
	Reset, AfterReset,
	WriteInit, NextInit,
	WaitUpdate, WaitUpdate2,
	StartWriteData, StartWriteData2,
	WriteData, WriteData2, NextData
} t_state;

t_state state = Reset, next_state = Reset;


// state flip-flops
always_ff@(posedge in_clk, posedge in_rst) begin
	// reset
	if(in_rst == 1'b1) begin
		state <= Reset;

		init_ctr <= 1'b0;
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

		last_byte_finished <= byte_finished;
	end
end


// state combinatorics
always_comb begin
	// defaults
	next_state = state;
	next_init_ctr = init_ctr;
	next_x_ctr = x_ctr;
	next_y_ctr = y_ctr;

	wait_ctr_max = WAIT_RESET;
	serial_enable = 1'b0;
	vid_rst = 1'b0;
	vid_cmd = 1'b0;
	data = 0;

	case(state)
		// ----------------------------------------------------
		// reset
		Reset: begin
			vid_rst = 1'b1;

			wait_ctr_max = WAIT_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = AfterReset;
		end

		AfterReset: begin
			wait_ctr_max = WAIT_AFTER_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = WriteInit;
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write init data
		WriteInit: begin
			serial_enable = 1'b1;
			data = init_data[init_ctr];
			vid_cmd = init_cmd[init_ctr];

			if(bus_cycle == 1'b1)
				next_state = NextInit;
		end

		// next init data byte
		NextInit: begin
			if(serial_ready == 1'b1) begin
				if(init_ctr == 1'b0) begin
					// next byte with wait
					wait_ctr_max = WAIT_AFTER_RESET;
					if(wait_ctr == wait_ctr_max) begin
						next_init_ctr = $size(init_ctr)'(init_ctr + 1'b1);
						next_state = WriteInit;
					end
				end else if(init_ctr + 1'b1 == INIT_BYTES) begin
					// last byte
					next_init_ctr = 1'b0;
					next_state = WaitUpdate;
				end else begin
					// next byte without wait
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
			if(in_update == 1'b1) begin
				next_state = StartWriteData;
			end
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// start writing to data ram [ctrl, p. 202]
		StartWriteData: begin
			serial_enable = 1'b1;
			data = 8'h2c;
			vid_cmd = 1'b0;

			if(bus_cycle == 1'b1)
				next_state = StartWriteData2;
		end

		StartWriteData2: begin
			if(serial_ready == 1'b1)
				next_state = WriteData;
		end
		// ----------------------------------------------------


		// ----------------------------------------------------
		// write first byte of the pixel data
		WriteData: begin
			serial_enable = 1'b1;
			vid_cmd = 1'b1;

			if(in_testpattern == 1'b1)
				data = pattern[PIXEL_BITS - 1 : PIXEL_BITS/2];
			else
				data = in_pixel[PIXEL_BITS - 1 : PIXEL_BITS/2];

			if(bus_cycle == 1'b1)
				next_state = WriteData2;
		end

		// write second byte of the pixel data
		WriteData2: begin
			serial_enable = 1'b1;
			vid_cmd = 1'b1;

			if(in_testpattern == 1'b1)
				data = pattern[PIXEL_BITS/2 - 1 : 0];
			else
				data = in_pixel[PIXEL_BITS/2 - 1 : 0];

			if(bus_cycle == 1'b1)
				next_state = NextData;
		end

		// next pixel
		NextData: begin
			vid_cmd = 1'b1;

			if(serial_ready == 1'b1) begin
				if(y_ctr + 1 == SCREEN_HEIGHT) begin
					// at last line
					if(x_ctr + 1 == SCREEN_WIDTH) begin
						// all finished
						next_x_ctr = 1'b0;
						next_y_ctr = 1'b0;
						next_state = WaitUpdate;
					end else begin
						next_x_ctr = $size(x_ctr)'(x_ctr + 1'b1);
						next_state = WriteData;
					end
				end else begin
					// before last line
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
		end
		// ----------------------------------------------------
	endcase

`ifdef __IN_SIMULATION__
	$display("*** video_serial: %s, x=%d, y=%d, init=%d, rst=%b, cmd=%b, ena=%b, rdy=%b, dat=%x. ***",
		state.name(), x_ctr, y_ctr, init_ctr, vid_rst, vid_cmd,
		serial_enable, serial_ready, init_data[init_ctr]);
`endif
end
// --------------------------------------------------------------------

endmodule
