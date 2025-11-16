/**
 * pixel lc display using serial 3/4-wire bus protocol and a fixed init sequence
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 3-may-2025
 * @license see 'LICENSE' file
 *
 * references:
 *     - [lcd] https://www.lcd-module.de/eng/pdf/zubehoer/st7565r.pdf
 */


module pixlcd_3wire
#(
	// clock frequency
	parameter MAIN_CLK     = 50_000_000,

	// word length and address of the LCD
	parameter BUS_DATABITS = 8,

	// number of characters on the LCD
	parameter LCD_COLS     = 128,
	parameter LCD_PAGES    = 8,
	parameter LCD_DATABITS = BUS_DATABITS,

	// explicitely set the column on data writing
	parameter SET_COL      = 1
)
(
	// clock and reset
	input wire in_clk, in_rst,

	// reset and register select for lcd
	output wire out_lcd_reset,
	output wire out_lcd_regsel,  // command (0) or data (1)

	// update the display
	input wire in_update,

	// serial bus interface
	input wire in_bus_ready, in_bus_next,
	output wire out_bus_enable,
	output wire [BUS_DATABITS - 1 : 0] out_bus_data,
	input wire [BUS_DATABITS - 1 : 0] in_bus_data,

	// display buffer
	input wire [LCD_DATABITS - 1 : 0] in_mem_word,

	// current column and page
	output [$clog2(LCD_COLS) : 0] out_column,
	output [$clog2(LCD_PAGES) : 0] out_page
);



typedef enum {
	Wait_Reset, Reset, Resetted,
	ReadInitSeq, Wait_Init,
	Wait_PreUpdateDisplay, Pre_UpdateDisplay,
	UpdateDisplay_SetCol1, UpdateDisplay_SetCol2,
	UpdateDisplay_SetPage, UpdateDisplay_SetLine,
	UpdateDisplay,
	UpdateDisplay_Wait_Next, NextData
} t_state;

t_state state = Wait_Reset, next_state = Wait_Reset;
t_state state_afterwait = Wait_Reset, next_state_afterwait = Wait_Reset;


// delays
localparam const_wait_prereset = MAIN_CLK/1000*50;        // 50 ms
localparam const_wait_reset    = MAIN_CLK/1000*1;         // 1 ms
localparam const_wait_resetted = MAIN_CLK/1000*1;         // 1 ms
localparam const_wait_init     = MAIN_CLK/1_000_000*100;  // 100 us
localparam const_wait_update   = MAIN_CLK/1000*100;       // 100 ms

// the maximum of the above delays
localparam const_wait_max      = const_wait_update;

// busy wait counters
logic [$clog2(const_wait_max) : 0] wait_counter, wait_counter_max = 1'b0;



/**
 * lcd init commands
 * see p. 50 in [lcd]
 */
localparam [0 : 0] invert_h     = 1'b0;
localparam [0 : 0] invert_v     = 1'b1;
localparam [0 : 0] invert_disp  = 1'b0;
localparam [0 : 0] booster_on   = 1'b1;
localparam [0 : 0] regulator_on = 1'b1;
localparam [0 : 0] follower_on  = 1'b1;
localparam [1 : 0] booster      = 2'b00;
localparam [2 : 0] regulator    = 3'b111;
localparam [4 : 0] contrast     = 5'h07;
localparam [0 : 0] bias_V       = 1'b1;

localparam init_num_commands = 18;
logic [0 : init_num_commands - 1][LCD_DATABITS - 1 : 0] init_arr;
assign init_arr =
{
	8'he2,                    // reset, [lcd, p. 44]
	8'hae,                    // display off, [lcd, p. 41]
	8'b01_000000,             // start line 0, [lcd, p. 41]
	8'b1011_0000,             // start page 0, [lcd, p. 41]
	8'b0001_0000,             // start column 0, 1/2, [lcd, p. 42]
	8'b0000_0000,             // start column 0, 2/2
	8'ha2 | bias_V,           // bias voltage, [lcd, p. 43]
	8'ha0 | invert_h,         // h direction, [lcd, p. 42]
	8'hc0 | (invert_v << 3),  // v direction, [lcd, p. 45]
	8'ha6 | invert_disp,      // inversion, [lcd, p. 43]
	8'h20 | regulator,        // regulation ratio, [lcd, p. 45]
	8'h81,                    // contrast 1/2, [lcd, p. 45-46]
	8'h00 | contrast,         // contrast 2/2
	8'hf8,                    // booster 1/2, [lcd, pp. 48]
	8'h00 | booster,          // booster 2/2]
	8'h28 | (booster_on << 2 | regulator_on << 1 | follower_on),  // power, [lcd, p. 45]
	8'b1010010_0,             // pixels off, [lcd, p. 43]
	8'haf                     // display on, [lcd, p. 41]
};


// cycle counters
logic [$clog2(init_num_commands) : 0] init_cycle = 1'b0, next_init_cycle = 1'b0;
logic [$clog2(LCD_COLS) : 0] column = 1'b0, next_column = 1'b0;
logic [$clog2(LCD_PAGES) : 0] page = 1'b0, next_page = 1'b0;


// rising edge of serial bus next byte signal
wire next_byte_cycle = in_bus_next && ~byte_cycle_last;
logic byte_cycle_last = 1'b0;


// outputs
logic lcd_reset = 1'b0;
logic bus_enable = 1'b0;
logic [BUS_DATABITS - 1 : 0] bus_data = 1'b0;
logic regsel = 1'b0;

assign out_lcd_reset = lcd_reset;
assign out_bus_enable = bus_enable;
assign out_bus_data = bus_data;
assign out_lcd_regsel = regsel;
assign out_column = column;
assign out_page = page;



/**
 * state flip-flops
 */
always_ff@(posedge in_clk) begin
	// reset
	if(in_rst == 1'b1) begin
		// state register
		state <= Wait_Reset;
		state_afterwait <= Wait_Reset;

		// timer register
		wait_counter <= 1'b0;

		// counter registers
		init_cycle <= 1'b0;
		column <= 1'b0;
		page <= 1'b0;

		byte_cycle_last <= 1'b0;
	end

	// clock
	else begin
		// state register
		state <= next_state;
		state_afterwait <= next_state_afterwait;

		// timer register
		if(wait_counter == wait_counter_max) begin
			// reset timer counter
			wait_counter <= 1'b0;
		end else begin
			// next timer counter
			wait_counter <= wait_counter + 1'b1;
		end

		// counter registers
		init_cycle <= next_init_cycle;
		column <= next_column;
		page <= next_page;

		byte_cycle_last <= in_bus_next;
	end
end



/**
 * state combinatorics
 */
always_comb begin
	// defaults
	next_state = state;
	next_state_afterwait = state_afterwait;

	next_init_cycle = init_cycle;
	next_column = column;
	next_page = page;

	wait_counter_max = 1'b0;

	lcd_reset = 1'b1;

	regsel = 1'b0;
	bus_enable = 1'b0;
	bus_data = 1'b0;


	unique case(state)
		// --------------------------------------------------------------------
		// reset
		// --------------------------------------------------------------------
		Wait_Reset: begin
			wait_counter_max = const_wait_prereset;
			if(wait_counter == wait_counter_max)
				next_state = Reset;
		end

		Reset: begin
			lcd_reset = 1'b0;

			wait_counter_max = const_wait_reset;
			if(wait_counter == wait_counter_max)
				next_state = Resetted;
		end

		Resetted: begin
			wait_counter_max = const_wait_resetted;
			if(wait_counter == wait_counter_max)
				next_state = ReadInitSeq;
		end
		// --------------------------------------------------------------------


		// --------------------------------------------------------------------
		// write init sequence
		// --------------------------------------------------------------------
		ReadInitSeq: begin
			// next command byte
			if(next_byte_cycle == 1'b1) begin
				next_init_cycle = init_cycle + 1'b1;
				next_state = Wait_Init;
				next_state_afterwait = ReadInitSeq;
			end

			// end of all commands?
			if(init_cycle == init_num_commands) begin
				// sequence finished
				if(in_bus_ready == 1'b1) begin
					next_state = Wait_PreUpdateDisplay;
					next_init_cycle = 1'b0;
				end
			end else begin
				// transmit command
				bus_data = init_arr[init_cycle];
				bus_enable = 1'b1;
			end
		end

		Wait_Init: begin
			// wait for the timer
			wait_counter_max = const_wait_init;
			if(wait_counter == wait_counter_max) begin
				next_state = state_afterwait;
			end
		end
		// --------------------------------------------------------------------


		// --------------------------------------------------------------------
		// update display
		// --------------------------------------------------------------------
		Wait_PreUpdateDisplay: begin
			wait_counter_max = const_wait_update;
			if(wait_counter == wait_counter_max)
				next_state = Pre_UpdateDisplay;
		end

		Pre_UpdateDisplay: begin
			next_page = 1'b0;

			if(in_update == 1'b1) begin
				next_state = (SET_COL == 1 ? UpdateDisplay_SetLine : UpdateDisplay_SetPage);
			end
		end

		UpdateDisplay_SetLine: begin
			// set line address to 0
			bus_data = 8'b01_000000;
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1) begin
				next_state = Wait_Init;
				next_state_afterwait = UpdateDisplay_SetCol1;
			end
		end

		UpdateDisplay_SetCol1: begin
			// set column address (nibble 1)
			bus_data = 8'b0001_0000 | 4'((column & 8'hf0) >> 4);
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1) begin
				next_state = Wait_Init;
				next_state_afterwait = UpdateDisplay_SetCol2;
			end
		end

		UpdateDisplay_SetCol2: begin
			// set column address (nibble 2)
			bus_data = 8'b0000_0000 | 4'(column & 8'h0f);
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1) begin
				next_state = Wait_Init;
				next_state_afterwait = UpdateDisplay_SetPage;
			end
		end

		UpdateDisplay_SetPage: begin
			// set page address
			bus_data = 8'b1011_0000 | 4'(page & 4'hf);
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1)
				next_state = Wait_Init;
				next_state_afterwait = UpdateDisplay;
		end

		UpdateDisplay: begin
			// write pixels
			bus_data = in_mem_word;
			regsel = 1'b1;
			bus_enable = 1'b1;

			// next column
			if(next_byte_cycle == 1'b1)
				next_state = UpdateDisplay_Wait_Next;
		end

		UpdateDisplay_Wait_Next: begin
			bus_data = in_mem_word;
			regsel = 1'b1;

			// wait for command
			wait_counter_max = const_wait_init;
			if(wait_counter == wait_counter_max) begin
				// continue with display update
				next_state = NextData;
			end
		end

		NextData: begin
			if(in_bus_ready == 1'b1) begin
				if(page + 1'b1 == LCD_PAGES) begin
					// at last line
					if(column + 1'b1 == LCD_COLS) begin
						// sequence finished
						next_state = Wait_PreUpdateDisplay;
						next_column = 1'b0;
						next_page = 1'b0;
					end else begin
						next_column = column + 1'b1;
						next_state = UpdateDisplay;
					end
				end else begin
					// before last line
					if(column + 1'b1 == LCD_COLS) begin
						// end of column
						next_column = 1'b0;
						next_page = page + 1'b1;
						next_state = UpdateDisplay_SetPage;
					end else begin
						next_column = column + 1'b1;
						next_state = UpdateDisplay;
					end
				end
			end
		end
		// --------------------------------------------------------------------


		default: begin
			next_state = Wait_Reset;
		end

	endcase
end


endmodule
