/**
 * serial monochrome oled display (TODO)
 * @author Tobias Weber
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
	parameter SERIAL_BITS     = 8,

	parameter SCREEN_WIDTH    = 128,
	parameter SCREEN_HEIGHT   = 64,
	parameter SCREEN_PAGES    = SCREEN_HEIGHT / SERIAL_BITS,

	parameter MAIN_CLK        = 50_000_000,
	parameter SERIAL_CLK      = 400_000,

	parameter HCTR_BITS       = $clog2(SCREEN_WIDTH),
	parameter VCTR_BITS       = $clog2(SCREEN_PAGES)
 )
(
	// clock and reset
	input wire in_clk, in_rst,

	// draw frame
	input wire in_update,

	// pixel data
	input wire [SERIAL_BITS - 1 : 0] in_pixels,
	output wire [HCTR_BITS - 1 : 0] out_hpix,
	output wire [VCTR_BITS - 1 : 0] out_vpix,

	// serial interface
	inout wire inout_serial_clk,
	inout wire inout_serial
);


// --------------------------------------------------------------------
// wait timer register
// --------------------------------------------------------------------
`ifdef __IN_SIMULATION__
	localparam WAIT_RESET       = 1;
	localparam WAIT_UPDATE      = 1;
`else
	localparam WAIT_RESET       = MAIN_CLK/1000/1000*50; // 50 us
	localparam WAIT_UPDATE      = MAIN_CLK/1000*50;      // 50 ms, 20 Hz
`endif

logic [$clog2(WAIT_UPDATE /*largest value*/) : 0]
	wait_ctr = 1'b0, wait_ctr_max = 1'b0;
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// init data
// --------------------------------------------------------------------
localparam INIT_BYTES = 4;

// init sequence
logic [0 : INIT_BYTES - 1][SERIAL_BITS-1 : 0] init_data;
assign init_data =
{
	// TODO
	8'hff, 8'h11, 8'h01, 8'h10
};

// init data byte counter
reg [$clog2(INIT_BYTES) : 0] init_ctr = 0, next_init_ctr = 0;
// --------------------------------------------------------------------


// pixel counters
reg [HCTR_BITS - 1 : 0] x_ctr = 0, next_x_ctr = 0;
reg [VCTR_BITS - 1 : 0] y_ctr = 0, next_y_ctr = 0;


// --------------------------------------------------------------------
// serial interface
// --------------------------------------------------------------------
logic serial_enable, serial_ready, serial_error;
logic serial, serial_clk;

logic [SERIAL_BITS - 1 : 0] data;

logic byte_finished, last_byte_finished = 1'b0;
wire bus_cycle = byte_finished && ~last_byte_finished;
//wire bus_cycle_next = ~byte_finished && last_byte_finished;

// instantiate serial module
serial_2wire #(
	.BITS(SERIAL_BITS), .LOWBIT_FIRST(0),
`ifdef __IN_SIMULATION__
	.IGNORE_ERROR(1),
`else
	.IGNORE_ERROR(0),
`endif
	.MAIN_CLK_HZ(MAIN_CLK), .SERIAL_CLK_HZ(SERIAL_CLK)
)
serial_mod(
	.in_clk(in_clk), .in_rst(in_rst), .out_err(serial_error),
	.in_enable(serial_enable), .in_write(1'b1), .out_ready(serial_ready),
	.in_addr_write(8'b10101010), .in_addr_read(8'b10101011),
	.inout_clk(serial_clk), .inout_serial(serial),
	.in_parallel(data), .out_parallel(),
	.out_next_word(byte_finished)
);
// --------------------------------------------------------------------


// --------------------------------------------------------------------
// outputs
// --------------------------------------------------------------------
assign out_hpix = x_ctr;
assign out_vpix = y_ctr;

//assign inout_serial = serial;
//assign inout_serial_clk = serial_clk;
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
	data = 0;

	case(state)
		Reset: begin
			wait_ctr_max = WAIT_RESET;
			if(wait_ctr == wait_ctr_max)
				next_state = WriteInit;
		end

		// ----------------------------------------------------
		// write init data
		WriteInit: begin
			serial_enable = 1'b1;
			data = init_data[init_ctr];

			if(bus_cycle == 1'b1)
				next_state = NextInit;
		end

		NextInit: begin
			if(serial_ready == 1'b1) begin
				if(init_ctr + 1 == INIT_BYTES) begin
					next_state = WaitUpdate;
				end else begin
					next_init_ctr = $size(wait_ctr)'(init_ctr + 1'b1);
					next_state = WriteInit;
				end;
			end;
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
				next_state = WriteData;
			end
		end
		// ----------------------------------------------------

		// ----------------------------------------------------
		// write pixel data
		WriteData: begin
			serial_enable = 1'b1;
			data = in_pixels;

			if(bus_cycle == 1'b1)
				next_state = NextData;
		end

		// next pixel
		NextData: begin
			if(serial_ready == 1'b1) begin
				if(y_ctr + 1 == SCREEN_PAGES) begin
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
	$display("*** oled_serial: %s, x=%d, y=%d, init=%d, ena=%b, rdy=%b, dat=%x. ***",
		state.name(), x_ctr, y_ctr, init_ctr,
		serial_enable, serial_ready, init_data[init_ctr]);
`endif

end
// --------------------------------------------------------------------

endmodule
