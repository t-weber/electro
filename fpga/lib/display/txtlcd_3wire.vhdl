--
-- text lc display using serial 3/4-wire bus protocol and a fixed init sequence
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2020, dec-2023
-- @license see 'LICENSE' file
--
-- references for lcd:
--   - [lcd] https://www.lcd-module.de/fileadmin/pdf/doma/dogm204.pdf
--   - [ic]  https://www.lcd-module.de/fileadmin/eng/pdf/zubehoer/ssd1803a_2_0.pdf
-- reference for serial bus usage:
--   - https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity txtlcd_3wire is
	generic(
		-- clock frequency
		constant MAIN_CLK         : natural := 50_000_000;

		-- word length and address of the LCD
		constant BUS_NUM_DATABITS : natural := 8;

		-- number of characters on the LCD
		constant LCD_SIZE         : natural := 4*20;
		constant LCD_NUM_ADDRBITS : natural := 7;
		constant LCD_NUM_DATABITS : natural := BUS_NUM_DATABITS;

		-- use the lcd busy flag for waiting instead of the timers
		constant READ_BUSY_FLAG   : std_logic := '1'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- reset for LCD
		out_lcd_reset    : out std_logic;

		-- update the display
		in_update        : in std_logic;

		-- serial bus interface
		in_bus_ready, in_bus_next : in std_logic;
		out_bus_enable   : out std_logic;
		out_bus_data     : out std_logic_vector(BUS_NUM_DATABITS - 1 downto 0);
		in_bus_data      : in std_logic_vector(BUS_NUM_DATABITS - 1 downto 0);

		-- output current busy flag for debugging
		out_busy_flag    : out std_logic_vector(BUS_NUM_DATABITS - 1 downto 0);

		-- display buffer
		in_mem_word      : in std_logic_vector(LCD_NUM_DATABITS - 1 downto 0);
		out_mem_addr     : out std_logic_vector(LCD_NUM_ADDRBITS - 1 downto 0)
	);
end entity;



architecture txtlcd_3wire_impl of txtlcd_3wire is
	-- states
	type t_lcd_state is (
		Wait_Reset, Reset, Resetted,
		ReadInitSeq, Wait_Init,
		ReadBusyFlag_Cmd, ReadBusyFlag, ReadBusyFlag2,
		CheckBusyFlag,
		Wait_PreUpdateDisplay, Pre_UpdateDisplay,
		UpdateDisplay_Setup1, UpdateDisplay_Setup2,
		UpdateDisplay_Setup3, UpdateDisplay_Setup4,
		UpdateDisplay_Setup5,
		UpdateDisplay);

	signal lcd_state, next_lcd_state : t_lcd_state := Wait_Reset;
	signal cmd_after_busy_check, next_cmd_after_busy_check : t_lcd_state := Wait_Reset;


	signal byte_cycle_last, next_byte_cycle : std_logic := '0';

	signal busy_flag, next_busy_flag : std_logic_vector(
		BUS_NUM_DATABITS - 1 downto 0) := (others => '0');


	-- delays
	constant const_wait_prereset : natural := MAIN_CLK/1000*50;      -- 50 ms
	constant const_wait_reset    : natural := MAIN_CLK/1000_000*500; -- 500 us
	constant const_wait_resetted : natural := MAIN_CLK/1000*1;       -- 1 ms
	constant const_wait_init     : natural := MAIN_CLK/1000_000*100; -- 100 us
	constant const_wait_update   : natural := MAIN_CLK/1000*100;     -- 100 ms

	-- the maximum of the above delays
	constant const_wait_max      : natural := const_wait_update;

	-- busy wait counters
	signal wait_counter, wait_counter_max : natural range 0 to const_wait_max := 0;


	--
	-- lcd init commands
	-- see p. 5 in [lcd] and pp. 38-40 in [ic]
	--
	-- control bytes
	constant ctrl_command : std_logic_vector(BUS_NUM_DATABITS/2 - 1 downto 0) := "0001";
	constant ctrl_data    : std_logic_vector(BUS_NUM_DATABITS/2 - 1 downto 0) := "0101";
	constant ctrl_read    : std_logic_vector(BUS_NUM_DATABITS/2 - 1 downto 0) := "0011";

	-- options
	constant use_8bits : std_logic                        := '1';
	constant use_4lines : std_logic                       := '1';
	constant invert_h : std_logic                         := '1';
	constant invert_v : std_logic                         := '1';
	constant caret_on : std_logic                         := '0';
	constant blink_on : std_logic                         := '0';
	constant char_rom : std_logic_vector(1 downto 0)      := "00";

	constant booster_on : std_logic                       := '1';
	constant divider_on : std_logic                       := '1';
	constant divider_ratio : std_logic_vector(2 downto 0) := "110";
	constant divider_bias : std_logic_vector(1 downto 0)  := "11";
	constant contrast : std_logic_vector(5 downto 0)      := "110000";
	constant oscillator : std_logic_vector(2 downto 0)    := "011";
	constant temperature : std_logic_vector(2 downto 0)   := "010";

	constant fontheight_on : std_logic                    := '0';
	constant double_height : std_logic_vector(1 downto 0) := "00";
	constant use_longfont : std_logic                     := '0';
	constant shift_on : std_logic                         := '0';
	constant shift_disp_on : std_logic                    := '0';      -- otherwise shift caret
	constant shift_lines : std_logic_vector(3 downto 0)   := "0000";   -- lines 3-0
	constant scroll : std_logic_vector(5 downto 0)        := "000000"; -- scroll or shift
	constant caret_right : std_logic                      := '1';
	constant invert_caret : std_logic                     := '0';
	constant mirror_y : std_logic                         := '1';
	constant mirror_x : std_logic                         := '0';

	constant init_num_commands : natural := 22;
	type t_init_arr is array(0 to init_num_commands*3 - 1)
		of std_logic_vector(LCD_NUM_DATABITS/2 - 1 downto 0);
	constant init_arr : t_init_arr := (
		-- power, [ic, p. 38]
		ctrl_command, use_4lines & fontheight_on & '1' & '1', "001" & use_8bits,  -- re=1, is=1
		ctrl_command, "0010", "0000",  -- no sleep

		-- scrolling or shifting, [ic, pp. 39-40]
		ctrl_command, "01" & mirror_y & mirror_x, "0000",
		ctrl_command, '1' & use_longfont & invert_caret & use_4lines, "0000",
		ctrl_command, shift_lines, "0001",
		ctrl_command, scroll(3 downto 0), std_logic_vector'("11" & scroll(5 downto 4)),

		-- rom selection, [ic, p. 40]
		ctrl_command, "0010", "0111",
		ctrl_data,    std_logic_vector'(char_rom & "00"), "0000",

		-- select temperature, [ic, p. 40]
		ctrl_command, "0110", "0111",
		ctrl_data,    '0' & temperature, "0000",

		-- voltage divider, [ic, pp. 39-40]
		ctrl_command, use_4lines & fontheight_on & '1' & '0', "001" & use_8bits,  -- re=1, is=0
		ctrl_command, double_height & divider_bias(1) & shift_on, "0001",

		-- voltage divider, [ic, pp. 39-40]
		ctrl_command, use_4lines & fontheight_on & '0' & '1', "001" & use_8bits,  -- re=0, is=1
		ctrl_command, divider_bias(0) & oscillator, "0001",
		ctrl_command, std_logic_vector'('0' & booster_on & contrast(5 downto 4)), "0101",
		ctrl_command, contrast(3 downto 0), "0111",
		ctrl_command, divider_on & divider_ratio, "0110",

		-- scrolling or shifting [ic, p. 38]
		ctrl_command, use_4lines & fontheight_on & '0' & '0', "001" & use_8bits,  -- re=0, is=0
		ctrl_command, "01" & caret_right & shift_disp_on, "0000",

		-- turn on display, [ic, p. 38]
		ctrl_command, "11" & caret_on & blink_on, "0000",

		--ctrl_command, "0000", "0100" -- character ram address
		--ctrl_data, "1111", "0001",   -- define character 0 line 0
		--ctrl_data, "1011", "0001",   -- define character 0 line 1
		--ctrl_data, "0001", "0001",   -- define character 0 line 2
		--ctrl_data, "0001", "0001",   -- define character 0 line 3
		--ctrl_data, "0001", "0001",   -- define character 0 line 4
		--ctrl_data, "0001", "0001",   -- define character 0 line 5
		--ctrl_data, "0001", "0001",   -- define character 0 line 6
		--ctrl_data, "0000", "0000",   -- define character 0 line 7

		-- clear and return, [ic, p. 38]
		ctrl_command, "0001", "0000",
		ctrl_command, "0010", "0000"

		--ctrl_data, "0010", "0011",   -- test data -> 0x32 = '2'
		--ctrl_data, "0011", "0011"    -- test data -> 0x33 = '3'
	);


	-- cycle counters
	signal init_cycle, next_init_cycle         : natural range 0 to init_num_commands := 0;
	signal cmd_byte_cycle, next_cmd_byte_cycle : natural range 0 to 4 := 0;
	signal write_cycle, next_write_cycle       : integer range 0 to LCD_SIZE := 0;

begin

	-- rising edge of serial bus next byte signal
	next_byte_cycle <= in_bus_next and (not byte_cycle_last);

	-- output current busy flag for debugging
	out_busy_flag <= busy_flag;


	--
	-- state flip-flops
	--
	proc_ff : process(in_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			lcd_state <= Wait_Reset;
			cmd_after_busy_check <= Wait_Reset;

			-- timer register
			wait_counter <= 0;

			-- counter registers
			init_cycle <= 0;
			write_cycle <= 0;
			cmd_byte_cycle <= 0;

			byte_cycle_last <= '0';

			busy_flag <= (others => '0');

		-- clock
		elsif rising_edge(in_clk) then
			-- state register
			lcd_state <= next_lcd_state;
			cmd_after_busy_check <= next_cmd_after_busy_check;

			-- timer register
			if wait_counter = wait_counter_max then
				-- reset timer counter
				wait_counter <= 0;
			else
				-- next timer counter
				wait_counter <= wait_counter + 1;
			end if;

			-- counter registers
			init_cycle <= next_init_cycle;
			write_cycle <= next_write_cycle;
			cmd_byte_cycle <= next_cmd_byte_cycle;

			byte_cycle_last <= in_bus_next;

			busy_flag <= next_busy_flag;
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(in_bus_ready, in_mem_word, in_update,
		lcd_state, wait_counter, wait_counter_max,
		cmd_byte_cycle, write_cycle, init_cycle, next_byte_cycle,
		busy_flag, in_bus_data, cmd_after_busy_check)
	begin
		-- defaults
		next_lcd_state <= lcd_state;
		next_cmd_after_busy_check <= cmd_after_busy_check;

		next_init_cycle <= init_cycle;
		next_write_cycle <= write_cycle;
		next_cmd_byte_cycle <= cmd_byte_cycle;

		next_busy_flag <= busy_flag;

		wait_counter_max <= 0;

		out_lcd_reset <= '1';
		out_mem_addr <= (others => '0');

		out_bus_enable <= '0';
		out_bus_data <= (others => '0');


		-- fsm
		case lcd_state is

			----------------------------------------------------------------------
			-- reset
			----------------------------------------------------------------------
			when Wait_Reset =>
				wait_counter_max <= const_wait_prereset;
				if wait_counter = wait_counter_max then
					next_lcd_state <= Reset;
				end if;


			when Reset =>
				out_lcd_reset <= '0';

				wait_counter_max <= const_wait_reset;
				if wait_counter = wait_counter_max then
					next_lcd_state <= Resetted;
				end if;


			when Resetted =>
				wait_counter_max <= const_wait_resetted;
				if wait_counter = wait_counter_max then
					next_lcd_state <= ReadInitSeq;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- write init sequence
			----------------------------------------------------------------------
			when ReadInitSeq =>
				-- next command byte
				if next_byte_cycle = '1' then
					next_cmd_byte_cycle <= cmd_byte_cycle + 1;
				end if;

				-- end of current command?
				if cmd_byte_cycle = 3 then
					next_lcd_state <= Wait_Init;
					next_init_cycle <= init_cycle + 1;
					next_cmd_byte_cycle <= 0;

				-- transmit commands
				else
					-- end of all commands?
					if init_cycle = init_num_commands then
						-- sequence finished
						if in_bus_ready = '1' then
							next_lcd_state <= Wait_PreUpdateDisplay;
							next_init_cycle <= 0;
						end if;
					else
						-- put command on bus
						if cmd_byte_cycle = 0 then
							-- command
							out_bus_data <=
								init_arr(init_cycle*3 + cmd_byte_cycle)
								& "1111";
						else
							-- data
							out_bus_data <=
								"0000" &
								init_arr(init_cycle*3 + cmd_byte_cycle);
						end if;
						out_bus_enable <= '1';
					end if;
				end if;


			when Wait_Init =>
				if READ_BUSY_FLAG = '1' then
					-- wait until the busy flag is clear
					next_lcd_state <= ReadBusyFlag_Cmd;
					next_cmd_after_busy_check <= ReadInitSeq;
				else
					-- wait for the timer
					wait_counter_max <= const_wait_init;
					if wait_counter = wait_counter_max then
						-- continue with init sequence
						next_lcd_state <= ReadInitSeq;
					end if;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- read busy flag
			----------------------------------------------------------------------
			when ReadBusyFlag_Cmd =>
				out_bus_data <= ctrl_read & "1111";
				out_bus_enable <= '1';

				if next_byte_cycle = '1' then
					next_lcd_state <= ReadBusyFlag;
				end if;


			when ReadBusyFlag =>
				out_bus_data <= (others => '0');
				out_bus_enable <= '1';

				if next_byte_cycle = '1' then
					next_lcd_state <= ReadBusyFlag2;
				end if;


			when ReadBusyFlag2 =>
				if in_bus_ready = '1' then
					next_busy_flag <= in_bus_data;
					next_lcd_state <= CheckBusyFlag;
				end if;


			when CheckBusyFlag =>
				if busy_flag(7) = '0' then
					-- continue with next command
					next_lcd_state <= cmd_after_busy_check;
				else
					-- keep polling the busy flag
					next_lcd_state <= ReadBusyFlag;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- update display
			----------------------------------------------------------------------
			when Wait_PreUpdateDisplay =>
				wait_counter_max <= const_wait_update;
				if wait_counter = wait_counter_max then
					next_lcd_state <= Pre_UpdateDisplay;
				end if;


			when Pre_UpdateDisplay =>
				if in_update = '1' then
					if READ_BUSY_FLAG = '1' then
						-- wait until the busy flag is clear
						next_lcd_state <= ReadBusyFlag_Cmd;
						next_cmd_after_busy_check <= UpdateDisplay_Setup1;
					else
						next_lcd_state <= UpdateDisplay_Setup1;
					end if;
				end if;


			when UpdateDisplay_Setup1 =>
				-- control byte for return
				out_bus_data <= ctrl_command & "1111";
				out_bus_enable <= '1';

				if next_byte_cycle = '1' then
					next_lcd_state <= UpdateDisplay_Setup2;
				end if;


			when UpdateDisplay_Setup2 =>
				-- return: set display address to 0 (nibble 1)
				out_bus_data <= "00000010";
				out_bus_enable <= '1';

				if next_byte_cycle = '1' then
					next_lcd_state <= UpdateDisplay_Setup3;
				end if;


			when UpdateDisplay_Setup3 =>
				-- return: set display address to 0 (nibble 2)
				out_bus_data <= "00000000";
				out_bus_enable <= '1';

				if next_byte_cycle = '1' then
					next_lcd_state <= UpdateDisplay_Setup4;
				end if;


			when UpdateDisplay_Setup4 =>
				-- wait for command
				wait_counter_max <= const_wait_init;
				if wait_counter = wait_counter_max then
					-- continue with display update
					next_lcd_state <= UpdateDisplay_Setup5;
				end if;


			when UpdateDisplay_Setup5 =>
				-- control byte for data
				out_bus_data <= ctrl_data & "1111";
				out_bus_enable <= '1';

				if next_byte_cycle = '1' then
					next_lcd_state <= UpdateDisplay;
					next_write_cycle <= 0;
					next_cmd_byte_cycle <= 0;
				end if;


			when UpdateDisplay =>
				-- next data nibble
				if next_byte_cycle = '1' then
					next_cmd_byte_cycle <= cmd_byte_cycle + 1;
				end if;

				-- end of current data byte?
				if cmd_byte_cycle = 2 then
					-- next character
					next_write_cycle <= write_cycle + 1;
					next_cmd_byte_cycle <= 0;

				-- write characters
				else
					-- end of character data?
					if write_cycle = LCD_SIZE then
						-- sequence finished
						if in_bus_ready = '1' then
							next_lcd_state <= Wait_PreUpdateDisplay;
							next_write_cycle <= 0;
							next_cmd_byte_cycle <= 0;
						end if;
					else
						out_mem_addr <= int_to_logvec(write_cycle, LCD_NUM_ADDRBITS);
						out_bus_data <= "0000" &
							in_mem_word(cmd_byte_cycle*4 + 3 downto cmd_byte_cycle*4);
						out_bus_enable <= '1';
					end if;
				end if;
			----------------------------------------------------------------------


			when others =>
				next_lcd_state <= Wait_Reset;
		end case;
	end process;

end architecture;
