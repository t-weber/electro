/**
 * text lc display using serial 3/4-wire bus protocol and a fixed init sequence
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 20-april-2025
 * @license see 'LICENSE' file
 *
 * references:
 *     - [lcd] https://www.lcd-module.de/fileadmin/pdf/doma/dogm204.pdf
 *     - [ic]  https://www.lcd-module.de/fileadmin/eng/pdf/zubehoer/ssd1803a_2_0.pdf
 */


module txtlcd_3wire
#(
    // clock frequency
    parameter MAIN_CLK         = 50_000_000,

    // word length and address of the LCD
    parameter BUS_NUM_DATABITS = 8,

    // number of characters on the LCD
    parameter LCD_SIZE         = 4*20,
    parameter LCD_NUM_ADDRBITS = 7,
    parameter LCD_NUM_DATABITS = BUS_NUM_DATABITS,

    // use the lcd busy flag for waiting instead of the timers
    parameter READ_BUSY_FLAG   = 1
)
(
    // clock and reset
    input wire in_clk, in_rst,

    // reset for LCD
    output wire out_lcd_reset,

    // update the display
    input wire in_update,

    // serial bus interface
    input wire in_bus_ready, in_bus_next,
    output wire out_bus_enable,
    output wire [BUS_NUM_DATABITS - 1 : 0] out_bus_data,
    input wire [BUS_NUM_DATABITS - 1 : 0] in_bus_data,

    // output current busy flag for debugging
    output wire [BUS_NUM_DATABITS - 1 : 0] out_busy_flag,

    // display buffer
    input wire [LCD_NUM_DATABITS - 1 : 0] in_mem_word,
    output wire [LCD_NUM_ADDRBITS - 1 : 0] out_mem_addr
);



typedef enum {
	Wait_Reset, Reset, Resetted,
	ReadInitSeq, Wait_Init,
	ReadBusyFlag_Cmd, ReadBusyFlag, ReadBusyFlag2,
	CheckBusyFlag,
	Wait_PreUpdateDisplay, Pre_UpdateDisplay,
	UpdateDisplay_Setup1, UpdateDisplay_Setup2,
	UpdateDisplay_Setup3, UpdateDisplay_Setup4,
	UpdateDisplay_Setup5,
	UpdateDisplay
} t_lcd_state;

t_lcd_state lcd_state = Wait_Reset, next_lcd_state = Wait_Reset;
t_lcd_state cmd_after_busy_check = Wait_Reset, next_cmd_after_busy_check = Wait_Reset;


// delays
localparam const_wait_prereset = MAIN_CLK/1000*50;        // 50 ms
localparam const_wait_reset    = MAIN_CLK/1_000_000*500;  // 500 us
localparam const_wait_resetted = MAIN_CLK/1000*1;         // 1 ms
localparam const_wait_init     = MAIN_CLK/1_000_000*100;  // 100 us
localparam const_wait_update   = MAIN_CLK/1000*100;       // 100 ms

// the maximum of the above delays
localparam const_wait_max      = const_wait_update;

// busy wait counters
logic [$clog2(const_wait_max) : 0] wait_counter, wait_counter_max = 1'b0;


/**
 * lcd init commands
 * see p. 5 in [lcd] and pp. 38-40 in [ic]
 */
// control bytes
localparam [BUS_NUM_DATABITS/2 - 1 : 0] ctrl_command = 4'b0001;
localparam [BUS_NUM_DATABITS/2 - 1 : 0] ctrl_data    = 4'b0101;
localparam [BUS_NUM_DATABITS/2 - 1 : 0] ctrl_read    = 4'b0011;

// options
localparam [0 : 0] use_8bits     = 1'b1;
localparam [0 : 0] use_4lines    = 1'b1;
localparam [0 : 0] invert_h      = 1'b1;
localparam [0 : 0] invert_v      = 1'b1;
localparam [0 : 0] caret_on      = 1'b0;
localparam [0 : 0] blink_on      = 1'b0;
localparam [1 : 0] char_rom      = 2'b00;

localparam [0 : 0] booster_on    = 1'b1;
localparam [0 : 0] divider_on    = 1'b1;
localparam [2 : 0] divider_ratio = 3'b110;
localparam [1 : 0] divider_bias  = 2'b11;
localparam [5 : 0] contrast      = 6'b110000;
localparam [2 : 0] oscillator    = 3'b011;
localparam [2 : 0] temperature   = 3'b010;

localparam [0 : 0] fontheight_on = 1'b0;
localparam [1 : 0] double_height = 2'b00;
localparam [0 : 0] use_longfont  = 1'b0;
localparam [0 : 0] shift_on      = 1'b0;
localparam [0 : 0] shift_disp_on = 1'b0;      // otherwise shift caret
localparam [3 : 0] shift_lines   = 4'b0000;   // lines 3-0
localparam [5 : 0] scroll        = 6'b000000; // scroll or shift
localparam [0 : 0] caret_right   = 1'b1;
localparam [0 : 0] invert_caret  = 1'b0;
localparam [0 : 0] mirror_y      = 1'b1;
localparam [0 : 0] mirror_x      = 1'b0;

localparam init_num_commands = 22;
logic [0 : init_num_commands*3 - 1][LCD_NUM_DATABITS/2 - 1 : 0] init_arr;
assign init_arr =
{
	// power, [ic, p. 38]
	/*  1 */ ctrl_command, 4'b0011 | (use_4lines << 3) | (fontheight_on << 2), 4'b0010 | use_8bits,  // re=1, is=1
	/*  2 */ ctrl_command, 4'b0010, 4'b0000,  // no sleep

	// scrolling or shifting, [ic, pp. 39-40]
	/*  3 */ ctrl_command, 4'b0100 | (mirror_y << 1) | mirror_x, 4'b0000,
	/*  4 */ ctrl_command, 4'b1000 | (use_longfont << 2) | (invert_caret << 1) | use_4lines, 4'b0000,
	/*  5 */ ctrl_command, shift_lines, 4'b0001,
	/*  6 */ ctrl_command, 4'(scroll & 4'b1111), 4'b1100 | 4'((scroll & 6'b110000) >> 4),

	// rom selection, [ic, p. 40]
	/*  7 */ ctrl_command, 4'b0010, 4'b0111,
	/*  8 */ ctrl_data,    (4'(char_rom) << 2), 4'b0000,

	// select temperature, [ic, p. 40]
	/*  9 */ ctrl_command, 4'b0110, 4'b0111,
	/* 10 */ ctrl_data,    4'(temperature), 4'b0000,

	// voltage divider, [ic, pp. 39-40]
	/* 11 */ ctrl_command, 4'b0010 | (use_4lines << 3) | (fontheight_on << 2), 4'b0010 | use_8bits,  // re=1, is=0
	/* 12 */ ctrl_command, (4'(double_height) << 2) | 4'(divider_bias & 2'b10) | shift_on, 4'b0001,

	// voltage divider, [ic, pp. 39-40]
	/* 13 */ ctrl_command, 4'b0001 | (use_4lines << 3) | (fontheight_on << 2), 4'b0010 | use_8bits,  // re=0, is=1
	/* 14 */ ctrl_command, 4'((divider_bias & 2'b01) << 3) | 4'(oscillator), 4'b0001,
	/* 15 */ ctrl_command, 4'(booster_on << 2) | 4'((contrast & 6'b110000) >> 4), 4'b0101,
	/* 16 */ ctrl_command, 4'(contrast & 4'b1111), 4'b0111,
	/* 17 */ ctrl_command, 4'(divider_on << 3) | 4'(divider_ratio), 4'b0110,

	// scrolling or shifting [ic, p. 38]
	/* 18 */ ctrl_command, 4'b0000 | (use_4lines << 3) | (fontheight_on << 2), 4'b0010 | use_8bits,  // re=0, is=0
	/* 19 */ ctrl_command, 4'b0100 | (caret_right << 1) | shift_disp_on, 4'b0000,

	// turn on display, [ic, p. 38]
	/* 20 */ ctrl_command, 4'b1100 | (caret_on << 1) | blink_on, 4'b0000,

	// clear and return, [ic, p. 38]
	/* 21 */ ctrl_command, 4'b0001, 4'b0000,
	/* 22 */ ctrl_command, 4'b0010, 4'b0000
};


// cycle counters
logic [$clog2(init_num_commands) : 0] init_cycle = 1'b0, next_init_cycle = 1'b0;
logic [2 : 0] cmd_byte_cycle = 1'b0, next_cmd_byte_cycle = 1'b0;
logic [$clog2(LCD_SIZE) : 0] write_cycle = 1'b0, next_write_cycle = 1'b0;


// rising edge of serial bus next byte signal
wire next_byte_cycle = in_bus_next && (!byte_cycle_last);
logic byte_cycle_last = 1'b0;


// outputs
logic lcd_reset = 1'b0;
logic [LCD_NUM_ADDRBITS - 1 : 0] mem_addr = 1'b0;
logic bus_enable = 1'b0;
logic [BUS_NUM_DATABITS - 1 : 0] bus_data = 1'b0;
logic [BUS_NUM_DATABITS - 1 : 0] busy_flag = 1'b0, next_busy_flag = 1'b0;

assign out_lcd_reset = lcd_reset;
assign out_mem_addr = mem_addr;
assign out_bus_enable = bus_enable;
assign out_bus_data = bus_data;
assign out_busy_flag = busy_flag;  // output current busy flag for debugging



/**
 * state flip-flops
 */
always_ff@(posedge in_clk) begin
	// reset
	if(in_rst == 1'b1) begin
		// state register
		lcd_state <= Wait_Reset;
		cmd_after_busy_check <= Wait_Reset;

		// timer register
		wait_counter <= 1'b0;

		// counter registers
		init_cycle <= 1'b0;
		write_cycle <= 1'b0;
		cmd_byte_cycle <= 1'b0;

		byte_cycle_last <= 1'b0;

		busy_flag <= {BUS_NUM_DATABITS{1'b1}};
	end

	// clock
	else begin
		// state register
		lcd_state <= next_lcd_state;
		cmd_after_busy_check <= next_cmd_after_busy_check;

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
		write_cycle <= next_write_cycle;
		cmd_byte_cycle <= next_cmd_byte_cycle;

		byte_cycle_last <= in_bus_next;

		busy_flag <= next_busy_flag;
	end
end



/**
 * state combinatorics
 */
always_comb begin
	// defaults
	next_lcd_state = lcd_state;
	next_cmd_after_busy_check = cmd_after_busy_check;

	next_init_cycle = init_cycle;
	next_write_cycle = write_cycle;
	next_cmd_byte_cycle = cmd_byte_cycle;

	next_busy_flag = busy_flag;

	wait_counter_max = 1'b0;

	lcd_reset = 1'b1;
	mem_addr = 1'b0;

	bus_enable = 1'b0;
	bus_data = 1'b0;


	unique case({ lcd_state, cmd_byte_cycle }) inside
		// --------------------------------------------------------------------
		// reset
		// --------------------------------------------------------------------
		{ Wait_Reset, {$size(cmd_byte_cycle){1'b?}} }: begin
			wait_counter_max = const_wait_prereset;
			if(wait_counter == wait_counter_max)
				next_lcd_state = Reset;
		end

		{ Reset, {$size(cmd_byte_cycle){1'b?}} }: begin
			lcd_reset = 1'b0;
			next_busy_flag = {BUS_NUM_DATABITS{1'b1}};

			wait_counter_max = const_wait_reset;
			if(wait_counter == wait_counter_max)
				next_lcd_state = Resetted;
		end

		{ Resetted, {$size(cmd_byte_cycle){1'b?}} }: begin
			wait_counter_max = const_wait_resetted;
			if(wait_counter == wait_counter_max)
				next_lcd_state = ReadInitSeq;
		end
		// --------------------------------------------------------------------


		// --------------------------------------------------------------------
		// write init sequence
		// --------------------------------------------------------------------
		{ ReadInitSeq, $size(cmd_byte_cycle)'(0) }: begin
			// next command byte
			if(next_byte_cycle == 1'b1)
				next_cmd_byte_cycle = cmd_byte_cycle + 1'b1;

			// end of all commands?
			if(init_cycle == init_num_commands) begin
				// sequence finished
				if(in_bus_ready == 1'b1) begin
					next_lcd_state = Wait_PreUpdateDisplay;
					next_init_cycle = 1'b0;
				end
			end else begin
				// transmit command
				bus_data =
				{
					init_arr[init_cycle*3 + cmd_byte_cycle],
					4'b1111
				};
				bus_enable = 1'b1;
			end
		end

		[ { ReadInitSeq, $size(cmd_byte_cycle)'(1) } : { ReadInitSeq, $size(cmd_byte_cycle)'(2) } ]: begin
			// next command byte
			if(next_byte_cycle == 1'b1)
				next_cmd_byte_cycle = cmd_byte_cycle + 1'b1;

			// arguments for the command
			bus_data =
			{
				4'b0000,
				init_arr[init_cycle*3 + cmd_byte_cycle]
			};
			bus_enable = 1'b1;
		end

		{ ReadInitSeq, $size(cmd_byte_cycle)'(3) }: begin
			// end of current command
			next_lcd_state = Wait_Init;
			next_init_cycle = init_cycle + 1'b1;
			next_cmd_byte_cycle = 1'b0;
		end

		{ Wait_Init, {$size(cmd_byte_cycle){1'b?}} }: begin
			if(READ_BUSY_FLAG == 1'b1) begin
				// wait until the busy flag is clear
				next_lcd_state = ReadBusyFlag_Cmd;
				next_cmd_after_busy_check = ReadInitSeq;
			end else begin
				// wait for the timer
				wait_counter_max = const_wait_init;
				if(wait_counter == wait_counter_max) begin
					// continue with init sequence
					next_lcd_state = ReadInitSeq;
				end
			end
		end
		// --------------------------------------------------------------------


		// --------------------------------------------------------------------
		// read busy flag
		// --------------------------------------------------------------------
		{ ReadBusyFlag_Cmd, {$size(cmd_byte_cycle){1'b?}} }: begin
			bus_data = { ctrl_read, 4'b1111 };
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1)
				next_lcd_state = ReadBusyFlag;
		end

		{ ReadBusyFlag, {$size(cmd_byte_cycle){1'b?}} }: begin
			bus_data = 1'b0;
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1)
				next_lcd_state = ReadBusyFlag2;
		end

		{ ReadBusyFlag2, {$size(cmd_byte_cycle){1'b?}} }: begin
			if(in_bus_ready == 1'b1) begin
				next_busy_flag = in_bus_data;
				next_lcd_state = CheckBusyFlag;
			end
		end

		{ CheckBusyFlag, {$size(cmd_byte_cycle){1'b?}} }: begin
			if(busy_flag[7] == 1'b0) begin
				// continue with next command
				next_lcd_state = cmd_after_busy_check;
			end else begin
				// keep polling the busy flag
				next_lcd_state = ReadBusyFlag;
			end
		end
		// --------------------------------------------------------------------


		// --------------------------------------------------------------------
		// update display
		// --------------------------------------------------------------------
		{ Wait_PreUpdateDisplay, {$size(cmd_byte_cycle){1'b?}} }: begin
			wait_counter_max = const_wait_update;
			if(wait_counter == wait_counter_max)
				next_lcd_state = Pre_UpdateDisplay;
		end

		{ Pre_UpdateDisplay, {$size(cmd_byte_cycle){1'b?}} }: begin
			if(in_update == 1'b1) begin
				if(READ_BUSY_FLAG == 1'b1) begin
					// wait until the busy flag is clear
					next_lcd_state = ReadBusyFlag_Cmd;
					next_cmd_after_busy_check = UpdateDisplay_Setup1;
				end else begin
					next_lcd_state = UpdateDisplay_Setup1;
				end
			end
		end

		{ UpdateDisplay_Setup1, {$size(cmd_byte_cycle){1'b?}} }: begin
			// control byte for return
			bus_data = { ctrl_command, 4'b1111 };
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1)
				next_lcd_state = UpdateDisplay_Setup2;
		end

		{ UpdateDisplay_Setup2, {$size(cmd_byte_cycle){1'b?}} }: begin
			// return: set display address to 0 (nibble 1)
			bus_data = 8'b00000010;
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1)
				next_lcd_state = UpdateDisplay_Setup3;
		end

		{ UpdateDisplay_Setup3, {$size(cmd_byte_cycle){1'b?}} }: begin
			// return: set display address to 0 (nibble 2)
			bus_data = 8'b00000000;
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1)
				next_lcd_state = UpdateDisplay_Setup4;
		end

		{ UpdateDisplay_Setup4, {$size(cmd_byte_cycle){1'b?}} }: begin
			// wait for command
			wait_counter_max = const_wait_init;
			if(wait_counter == wait_counter_max) begin
				// continue with display update
				next_lcd_state = UpdateDisplay_Setup5;
			end
		end

		{ UpdateDisplay_Setup5, {$size(cmd_byte_cycle){1'b?}} }: begin
			// control byte for data
			bus_data = { ctrl_data, 4'b1111 };
			bus_enable = 1'b1;

			if(next_byte_cycle == 1'b1) begin
				next_lcd_state = UpdateDisplay;
				next_write_cycle = 1'b0;
				next_cmd_byte_cycle = 1'b0;
			end
		end

		[ { UpdateDisplay, $size(cmd_byte_cycle)'(0) } : { UpdateDisplay, $size(cmd_byte_cycle)'(1) } ]: begin
			// next data nibble
			if(next_byte_cycle == 1'b1)
				next_cmd_byte_cycle = cmd_byte_cycle + 1'b1;

			// write characters
			// end of character data?
			if(write_cycle == LCD_SIZE) begin
				// sequence finished
				if(in_bus_ready == 1'b1) begin
					next_lcd_state = Wait_PreUpdateDisplay;
					next_write_cycle = 1'b0;
					next_cmd_byte_cycle = 1'b0;
				end
			end else begin
				mem_addr = LCD_NUM_ADDRBITS'(write_cycle);
				bus_data =
				{
					4'b0000,
					in_mem_word[cmd_byte_cycle*4 + 3],
					in_mem_word[cmd_byte_cycle*4 + 2],
					in_mem_word[cmd_byte_cycle*4 + 1],
					in_mem_word[cmd_byte_cycle*4 + 0]
				};
				bus_enable = 1'b1;
			end
		end

		{ UpdateDisplay, $size(cmd_byte_cycle)'(2) }: begin
			// end of current data byte
			next_write_cycle = write_cycle + 1'b1;
			next_cmd_byte_cycle = 1'b0;
		end

		default: begin
			next_lcd_state = Wait_Reset;
		end
		// --------------------------------------------------------------------

	endcase
end


endmodule
