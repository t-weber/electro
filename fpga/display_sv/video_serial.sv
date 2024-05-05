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

		parameter SCREEN_HEIGHT = 64,
		parameter SCREEN_WIDTH  = 128,

		parameter MAIN_CLK      = 50_000_000,
		parameter SERIAL_CLK    = 1_000_000
	 )
	(
		// clock and reset
		input wire in_clk,
		input wire in_rst,

		// pixel data
		input wire [PIXEL_BITS-1 : 0] in_pixel,
		output wire [$clog2(SCREEN_WIDTH) : 0] out_hpix,
		output wire [$clog2(SCREEN_HEIGHT) : 0] out_vpix,

		// serial video interface
		output wire out_vid_rst,
		output wire out_vid_serial_clk,
		output wire out_vid_serial
	);


	typedef enum bit [$clog2(7) : 0] {
		Reset,
		WriteInit, NextInit,
		WriteData, WriteData2, NextData,
		Idle
	} t_state;
	t_state state = Reset, next_state = Reset;


	// init data
	localparam NUM_INIT_BYTES = 2;
	logic [NUM_INIT_BYTES][SERIAL_BITS-1 : 0] init_data = {
		8'hff, 8'h00  // TODO
	};

	// init data byte counter
	reg [$clog2(NUM_INIT_BYTES) : 0] init_ctr = 0, next_init_ctr = 0;


	logic enable, ready;
	logic vid_rst, serial, serial_clk;

	assign out_vid_rst = vid_rst;
	assign out_vid_serial = serial;
	assign out_vid_serial_clk = serial_clk;

	logic [SERIAL_BITS-1 : 0] data;

	logic byte_finished, last_byte_finished = 0;
	wire bus_cycle = byte_finished && ~last_byte_finished;
	wire bus_cycle_next = ~byte_finished && last_byte_finished;


	// pixel counter
	reg [$clog2(SCREEN_HEIGHT) : 0] y_ctr = 0, next_y_ctr = 0;
	reg [$clog2(SCREEN_WIDTH) : 0] x_ctr = 0, next_x_ctr = 0;


	// instantiate serial module
	serial #(
		.BITS(SERIAL_BITS), .LOWBIT_FIRST(0),
		.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK),
		.SERIAL_CLK_INACTIVE(1), .SERIAL_DATA_INACTIVE(0)
	)
	serial_mod(
		.in_clk(in_clk), .in_rst(in_rst),
		.in_parallel(data), .in_enable(enable),
		.out_serial(serial), .out_next_word(byte_finished),
		.out_ready(ready), .out_clk(serial_clk),
		.in_serial(serial)
	);


	// state flip-flops
	always_ff@(posedge in_clk, posedge in_rst) begin
		// reset
		if(in_rst == 1) begin
			state <= Reset;
			init_ctr <= 0;
			x_ctr <= 0;
			y_ctr <= 0;
			last_byte_finished <= 0;
		end

		// clock
		else begin
			state <= next_state;
			init_ctr <= next_init_ctr;
			x_ctr <= next_x_ctr;
			y_ctr <= next_y_ctr;
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

		enable = 0;
		vid_rst = 0;
		data = 0;

		$display("*** video_serial: %s, x=%d, y=%d. ***", state.name(), x_ctr, y_ctr);

		case(state)
			Reset: begin
				vid_rst = 1;
				next_state = WriteInit;
			end

			// ----------------------------------------------------
			// write init data
			WriteInit: begin
				enable = 1;
				data = init_data[init_ctr];

				if(bus_cycle == 1)
					next_state = NextInit;
			end

			// next init data byte
			NextInit: begin
				enable = 1;
				if(init_ctr + 1 == NUM_INIT_BYTES) begin
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
				enable = 1;
				data = in_pixel[PIXEL_BITS - 1 : PIXEL_BITS/2];

				if(bus_cycle == 1)
					next_state = WriteData2;
			end

			// write second byte of the pixel data
			WriteData2: begin
				enable = 1;
				data = in_pixel[PIXEL_BITS/2 - 1 : 0];

				if(bus_cycle == 1)
					next_state = NextData;
			end

			// next pixel
			NextData: begin
				if(y_ctr + 1 == SCREEN_HEIGHT) begin
					if(x_ctr + 1 == SCREEN_WIDTH) begin
						enable = 0;
						next_state = Idle;
					end else begin
						enable = 1;
						next_x_ctr = x_ctr + 1;
						next_state = WriteData;
					end
				end else begin
					if(x_ctr + 1 == SCREEN_WIDTH) begin
						enable = 1;
						next_x_ctr = 0;
						next_y_ctr = y_ctr + 1;
						next_state = WriteData;
					end else begin
						enable = 1;
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

endmodule
