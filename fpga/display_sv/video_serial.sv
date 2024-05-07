/**
 * display with serial interface
 * @author Tobias Weber
 * @date 4-may-2024
 * @license see 'LICENSE' file
 */


module video_serial
	#(
		parameter SERIAL_BITS   = 8,
		parameter PIXEL_BITS    = 16,

		parameter SCREEN_WIDTH  = 128,
		parameter SCREEN_HEIGHT = 64,

		parameter MAIN_CLK      = 50_000_000,
		parameter SERIAL_CLK    = 1_000_000,

		parameter HCTR_BITS     = $clog2(SCREEN_WIDTH),
		parameter VCTR_BITS     = $clog2(SCREEN_HEIGHT),

		parameter USE_TESTPATTERN = 1
	 )
	(
		// clock and reset
		input wire in_clk, in_rst,

		// show test pattern?
		input wire in_testpattern,

		// pixel data
		input wire [PIXEL_BITS - 1 : 0] in_pixel,
		output wire [HCTR_BITS - 1 : 0] out_hpix,
		output wire [VCTR_BITS - 1 : 0] out_vpix,

		// serial video interface
		output wire out_vid_rst,
		output wire out_vid_serial_clk,
		output wire out_vid_serial
	);


	// --------------------------------------------------------------------
	// wait timer register
	// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam WAIT_RESET = 1;
`else
	localparam WAIT_RESET = MAIN_CLK/1000*100;  // 100 ms
`endif

	logic [$clog2(WAIT_RESET) : 0] wait_ctr = 0, wait_ctr_max = 0;
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// init data
	// --------------------------------------------------------------------
	localparam INIT_BYTES = 2;
	logic [INIT_BYTES][SERIAL_BITS-1 : 0] init_data = {
		8'hff, 8'h00  // TODO
	};

	// init data byte counter
	reg [$clog2(INIT_BYTES) : 0] init_ctr = 0, next_init_ctr = 0;
	// --------------------------------------------------------------------


	// pixel counters
	reg [HCTR_BITS - 1 : 0] x_ctr = 0, next_x_ctr = 0;
	reg [VCTR_BITS - 1 : 0] y_ctr = 0, next_y_ctr = 0;


	// video interface
	logic vid_rst;


	// --------------------------------------------------------------------
	// serial interface
	// --------------------------------------------------------------------
	logic serial_enable, serial_ready;
	logic serial, serial_clk;
	logic [SERIAL_BITS-1 : 0] data;

	logic byte_finished, last_byte_finished = 0;
	wire bus_cycle = byte_finished && ~last_byte_finished;
	wire bus_cycle_next = ~byte_finished && last_byte_finished;

	serial #(
		.BITS(SERIAL_BITS), .LOWBIT_FIRST(0),
		.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
		.SERIAL_CLK_INACTIVE(1), .SERIAL_DATA_INACTIVE(0)
	)
	serial_mod(
		.in_clk(in_clk), .in_rst(in_rst),
		.in_parallel(data), .in_enable(serial_enable),
		.out_serial(serial), .out_next_word(byte_finished),
		.out_ready(serial_ready), .out_clk(serial_clk),
		.in_serial(serial)
	);
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// generate test pattern
	// --------------------------------------------------------------------
	// test pattern values
	reg [PIXEL_BITS - 1 : 0] pattern;


	generate
	if(USE_TESTPATTERN) begin
		testpattern
		#(
			.HPIX(SCREEN_WIDTH), .VPIX(SCREEN_HEIGHT),
			.PIXEL_BITS(PIXEL_BITS),
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
	assign out_vid_serial = serial;
	assign out_vid_serial_clk = serial_clk;
	// --------------------------------------------------------------------


	// --------------------------------------------------------------------
	// states
	// --------------------------------------------------------------------
	typedef enum bit [$clog2(7) : 0] {
		Reset,
		WriteInit, NextInit,
		WriteData, WriteData2, NextData,
		Idle
	} t_state;
	t_state state = Reset, next_state = Reset;


	// state flip-flops
	always_ff@(posedge in_clk, posedge in_rst) begin
		// reset
		if(in_rst == 1) begin
			state <= Reset;

			init_ctr <= 0;
			x_ctr <= 0;
			y_ctr <= 0;

			// timer register
			wait_ctr <= 0;

			last_byte_finished <= 0;
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
				wait_ctr <= 0;
			end else begin
				// next timer counter
				wait_ctr <= wait_ctr + 1;
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

		serial_enable = 0;
		vid_rst = 0;
		data = 0;

		$display("*** video_serial: %s, x=%d, y=%d. ***", state.name(), x_ctr, y_ctr);

		case(state)
			Reset: begin
				vid_rst = 1;

				wait_ctr_max = WAIT_RESET;
				if(wait_ctr == wait_ctr_max)
					next_state = WriteInit;
			end

			// ----------------------------------------------------
			// write init data
			WriteInit: begin
				serial_enable = 1;
				data = init_data[init_ctr];

				if(bus_cycle == 1)
					next_state = NextInit;
			end

			// next init data byte
			NextInit: begin
				serial_enable = 1;
				if(init_ctr + 1 == INIT_BYTES) begin
					next_state = WriteData;
				end else begin
					next_init_ctr = init_ctr + 1;
					next_state = WriteInit;
				end;
			end
			// ----------------------------------------------------

			// ----------------------------------------------------
			// write first byte of the pixel data
			WriteData: begin
				serial_enable = 1;
				if(in_testpattern)
					data = pattern[PIXEL_BITS - 1 : PIXEL_BITS/2];
				else
					data = in_pixel[PIXEL_BITS - 1 : PIXEL_BITS/2];

				if(bus_cycle == 1)
					next_state = WriteData2;
			end

			// write second byte of the pixel data
			WriteData2: begin
				serial_enable = 1;
				if(in_testpattern)
					data = pattern[PIXEL_BITS/2 - 1 : 0];
				else
					data = in_pixel[PIXEL_BITS/2 - 1 : 0];

				if(bus_cycle == 1)
					next_state = NextData;
			end

			// next pixel
			NextData: begin
				if(y_ctr + 1 == SCREEN_HEIGHT) begin
					if(x_ctr + 1 == SCREEN_WIDTH) begin
						serial_enable = 0;
						next_state = Idle;
					end else begin
						serial_enable = 1;
						next_x_ctr = x_ctr + 1;
						next_state = WriteData;
					end
				end else begin
					if(x_ctr + 1 == SCREEN_WIDTH) begin
						serial_enable = 1;
						next_x_ctr = 0;
						next_y_ctr = y_ctr + 1;
						next_state = WriteData;
					end else begin
						serial_enable = 1;
						next_x_ctr = x_ctr + 1;
						next_state = WriteData;
					end
				end;
			end
			// ----------------------------------------------------

			Idle: begin
			end
		endcase
	end
	// --------------------------------------------------------------------

endmodule
