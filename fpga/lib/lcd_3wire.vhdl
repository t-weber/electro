--
-- LC display using serial 3/4-wire bus protocol and a fixed init sequence
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2020, dec-2023
-- @license see 'LICENSE' file
--
-- references for lcd:
--   - https://www.lcd-module.de/fileadmin/pdf/doma/dogm204.pdf
--   - https://www.lcd-module.de/fileadmin/eng/pdf/zubehoer/ssd1803a_2_0.pdf
-- reference for serial bus usage:
--   - https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity lcd_3wire is
	generic(
		-- clock
		constant main_clk : natural := 50_000_000;

		-- word length and address of the LCD
		constant bus_num_databits : natural := 8;

		-- number of characters on the LCD
		constant lcd_size : natural := 4*20;
		constant lcd_num_addrbits : natural := 7;
		constant lcd_num_databits : natural := bus_num_databits;

		-- start address of the display buffer in the memory
		constant mem_start_addr : natural := 0
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- reset for LCD
		out_lcd_reset : out std_logic;
		
		-- update the display
		in_update : in std_logic;

		-- serial bus interface
		in_bus_ready, in_bus_next : in std_logic;
		out_bus_enable : out std_logic;
		out_bus_data : out std_logic_vector(bus_num_databits-1 downto 0);

		-- display buffer
		in_mem_word : in std_logic_vector(lcd_num_databits-1 downto 0);
		out_mem_addr : out std_logic_vector(lcd_num_addrbits-1 downto 0)
	);
end entity;



architecture lcd_3wire_impl of lcd_3wire is
	-- states
	type t_lcd_state is (
		Wait_Reset, Reset, Resetted,
		ReadInitSeq, Wait_Init,
		Wait_PreUpdateDisplay, Pre_UpdateDisplay,
		UpdateDisplay_Setup1, UpdateDisplay_Setup2,
		UpdateDisplay_Setup3, UpdateDisplay_Setup4,
		UpdateDisplay_Setup5,
		--Wait_UpdateDisplay,
		UpdateDisplay);
	signal lcd_state, next_lcd_state : t_lcd_state := Wait_reset;
	signal byte_cycle_last, next_byte_cycle : std_logic := '0';

	-- delays
	constant const_wait_prereset : natural := main_clk/1000*50;           -- 50 ms
	constant const_wait_reset : natural := main_clk/1000_000*500;         -- 500 us
	constant const_wait_resetted : natural := main_clk/1000*1;            -- 1 ms
	constant const_wait_init : natural := main_clk/1000_000*100;          -- 100 us
	constant const_wait_PreUpdateDisplay : natural := main_clk/1000*100;  -- 100 ms
	--constant const_wait_UpdateDisplay : natural := main_clk/1000_000*500; -- 500 us

	-- the maximum of the above delays
	constant const_wait_max : natural := const_wait_PreUpdateDisplay;

	-- busy wait counters
	signal wait_counter, wait_counter_max : natural range 0 to const_wait_max := 0;

	-- lcd with 4-lines and 20 characters per line
	constant static_lcd_size : natural := 4 * 20;

	-- control bytes
	constant ctrl_command : std_logic_vector(bus_num_databits-1 downto 0) := "00011111"; --"11111000";
	constant ctrl_data : std_logic_vector(bus_num_databits-1 downto 0) := "01011111"; --"11111010";

	-- lcd init commands
	-- see p. 5 in https://www.lcd-module.de/fileadmin/pdf/doma/dogm204.pdf
	constant init_num_commands : natural := 21;
	type t_init_arr is array(0 to init_num_commands*3 - 1) of std_logic_vector(lcd_num_databits-1 downto 0);
	constant init_arr : t_init_arr := (
		ctrl_command, "00001011", "00000011",  -- 8 bit, 4 lines, normal font size, re=1, is=1
		ctrl_command, "00000010", "00000000",  -- no sleep
		ctrl_command, "00000110", "00000000",  -- shift direction (mirror view)
		ctrl_command, "00001001", "00000000",  -- short font width, no caret inversion, 4 lines
		ctrl_command, "00000000", "00000001",  -- scroll (or shift) off for lines 3-0
		ctrl_command, "00000000", "00001100",  -- scroll amount
		ctrl_command, "00000010", "00000111",  -- select rom
		ctrl_data,    "00000000", "00000000",  -- first rom
		--ctrl_data, "00000100", "00000000",   -- second rom
		--ctrl_data, "00001000", "00000000",   -- third rom
		ctrl_command, "00000110", "00000111",  -- select temperature control
		ctrl_data, "00000010", "00000000",     -- temperature

		ctrl_command, "00001010", "00000011",  -- 8 bit, 4 lines, normal font size, re=1, is=0
		ctrl_command, "00000010", "00000001",  -- 2 double-height bits, voltage divider bias bit 1, shift off (scroll on)

		ctrl_command, "00001001", "00000011",  -- 8 bit, 4 lines, no blinking, no reversing, re=0, is=1
		ctrl_command, "00001011", "00000001",  -- voltage divider bias bit 0, oscillator bits 2-0
		ctrl_command, "00000111", "00000101",  -- no icon, voltage regulator, contrast bits 5 and 4
		ctrl_command, "00000000", "00000111",  -- contrast bits 3-0
		ctrl_command, "00001110", "00000110",  -- voltage divider, amplifier bits 2-0
		
		ctrl_command, "00001000", "00000011",  -- 8 bit, 4 lines, no blinking, no reversing, re=0, is=0
		ctrl_command, "00000110", "00000000",  -- caret moving right, no display shifting
		ctrl_command, "00001100", "00000000",  -- turn on display, no caret, no blinking
		--ctrl_command, "00000000", "00000100" -- character ram address
		--ctrl_data, "00001111", "00000001",   -- define character 0 line 0
		--ctrl_data, "00001011", "00000001",   -- define character 0 line 1
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 2
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 3
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 4
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 5
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 6
		--ctrl_data, "00000000", "00000000",   -- define character 0 line 7
		ctrl_command, "00000001", "00000000"   -- clear

		--ctrl_data, "00000010", "00000011",   -- test data -> 0x32 = '2'
		--ctrl_data, "00000011", "00000011"    -- test data -> 0x33 = '3'
	);

	-- cycle counters
	signal init_cycle, next_init_cycle : natural range 0 to init_num_commands := 0;
	signal cmd_byte_cycle, next_cmd_byte_cycle : natural range 0 to 4 := 0;
	signal write_cycle, next_write_cycle : integer range 0 to lcd_size := 0;

begin

	-- rising edge of serial bus next byte signal
	next_byte_cycle <= in_bus_next and (not byte_cycle_last);


	--
	-- flip-flops
	--
	proc_ff : process(in_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			lcd_state <= Wait_Reset;
			
			-- timer register
			wait_counter <= 0;

			-- counter registers
			init_cycle <= 0;
			write_cycle <= 0;
			cmd_byte_cycle <= 0;

			byte_cycle_last <= '0';

		-- clock
		elsif rising_edge(in_clk) then
			-- state register
			lcd_state <= next_lcd_state;

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
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(in_bus_ready, in_mem_word, in_update,
		lcd_state, wait_counter, wait_counter_max,
		cmd_byte_cycle, write_cycle, init_cycle, next_byte_cycle)
	begin
		-- defaults
		next_lcd_state <= lcd_state;
	
		next_init_cycle <= init_cycle;
		next_write_cycle <= write_cycle;
		next_cmd_byte_cycle <= cmd_byte_cycle;

		wait_counter_max <= 0;

		out_lcd_reset <= '1';
		out_mem_addr <= (others => '0');

		out_bus_enable <= '0';
		out_bus_data <= (others => '0');


		-- fsm
		case lcd_state is

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
						out_bus_data <= init_arr(init_cycle*3 + cmd_byte_cycle);
						out_bus_enable <= '1';
					end if;
				end if;


			when Wait_Init =>
				wait_counter_max <= const_wait_init;
				if wait_counter = wait_counter_max then
					-- continue with init sequence
					next_lcd_state <= ReadInitSeq;
				end if;


			when Wait_PreUpdateDisplay =>
				wait_counter_max <= const_wait_PreUpdateDisplay;
				if wait_counter = wait_counter_max then
					next_lcd_state <= Pre_UpdateDisplay;
				end if;


			when Pre_UpdateDisplay =>
				if in_update = '1' then
					next_lcd_state <= UpdateDisplay_Setup1;
				end if;


			when UpdateDisplay_Setup1 =>
				-- control byte for return
				out_bus_data <= ctrl_command;
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
				out_bus_data <= ctrl_data;
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
					--next_lcd_state <= Wait_UpdateDisplay;
					next_write_cycle <= write_cycle + 1;
					next_cmd_byte_cycle <= 0;

				-- write characters
				else
					-- end of character data?
					if write_cycle = static_lcd_size then
						-- sequence finished
						if in_bus_ready = '1' then
							next_lcd_state <= Wait_PreUpdateDisplay;
							next_write_cycle <= 0;
							next_cmd_byte_cycle <= 0;
						end if;
					else
						out_mem_addr <= int_to_logvec(
							write_cycle + mem_start_addr, lcd_num_addrbits);
						out_bus_data <= "0000" &
							in_mem_word(cmd_byte_cycle*4 + 3) &
							in_mem_word(cmd_byte_cycle*4 + 2) &
							in_mem_word(cmd_byte_cycle*4 + 1) &
							in_mem_word(cmd_byte_cycle*4 + 0);
						--out_bus_data <= "00000010";
						out_bus_enable <= '1';
					end if;
				end if;


			--when Wait_UpdateDisplay =>
			--	wait_counter_max <= const_wait_UpdateDisplay;
			--	if wait_counter = wait_counter_max then
			--		-- continue with display update
			--		next_lcd_state <= UpdateDisplay;
			--	end if;


			when others =>
				next_lcd_state <= Wait_Reset;
		end case;
	end process;

end architecture;
