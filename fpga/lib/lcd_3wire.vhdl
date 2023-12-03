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
		in_bus_ready : in std_logic;
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
		Wait_UpdateDisplay, Pre_UpdateDisplay, UpdateDisplay);
	signal lcd_state, next_lcd_state : t_lcd_state := Wait_reset;
	signal bus_last_ready, bus_cycle : std_logic := '0';

	-- delays
	constant const_wait_prereset : natural := main_clk/1000*50;        -- 50 ms
	constant const_wait_reset : natural := main_clk/1000_000*500;      -- 500 us
	constant const_wait_resetted : natural := main_clk/1000*1;         -- 1 ms
	constant const_wait_init : natural := main_clk/1000*1;             -- 1 ms
	constant const_wait_UpdateDisplay : natural := main_clk/1000*200;  -- 200 ms

	-- the maximum of the above delays
	constant const_wait_max : natural := const_wait_UpdateDisplay;

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
		ctrl_command, "00000011", "00001011",  -- 8 bit, 4 lines, normal font size, re=1, is=1
		ctrl_command, "00000000", "00000010",  -- no sleep
		ctrl_command, "00000000", "00000110",  -- shift direction (mirror view)
		ctrl_command, "00000000", "00001001",  -- short font width, no caret inversion, 4 lines
		ctrl_command, "00000001", "00000000",  -- scroll (or shift) off for lines 3-0
		ctrl_command, "00001100", "00000000",  -- scroll amount
		ctrl_command, "00000111", "00000010",  -- select rom
		ctrl_data,    "00000000", "00000000",  -- first rom
		--ctrl_data, "00000000", "00000100" ,  -- second rom
		--ctrl_data, "00000000", "00001000",   -- third rom
		ctrl_command, "00000111", "00000110",  -- select temperature control
		ctrl_data, "00000000", "00000010",     -- temperature

		ctrl_command, "00000011", "00001010",  -- 8 bit, 4 lines, normal font size, re=1, is=0
		ctrl_command, "00000001", "00000010",  -- 2 double-height bits, voltage divider bias bit 1, shift off (scroll on)

		ctrl_command, "00000011", "00001001",  -- 8 bit, 4 lines, no blinking, no reversing, re=0, is=1
		ctrl_command, "00000001", "00001011",  -- voltage divider bias bit 0, oscillator bits 2-0
		ctrl_command, "00000101", "00000111",  -- no icon, voltage regulator, contrast bits 5 and 4
		ctrl_command, "00000111", "00000000",  -- contrast bits 3-0
		ctrl_command, "00000110", "00001110",  -- voltage divider, amplifier bits 2-0
		
		ctrl_command, "00000011", "00001000",  -- 8 bit, 4 lines, no blinking, no reversing, re=0, is=0
		ctrl_command, "00000000", "00000110",  -- caret moving right, no display shifting
		ctrl_command, "00000000", "00001100",  -- turn on display, no caret, no blinking
		--ctrl_command, "00000100", "00000000",  -- character ram address
		--ctrl_data, "00000001", "00001111",   -- define character 0 line 0
		--ctrl_data, "00000001", "00001011",   -- define character 0 line 1
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 2
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 3
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 4
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 5
		--ctrl_data, "00000001", "00000001",   -- define character 0 line 6
		--ctrl_data, "00000000", "00000000",   -- define character 0 line 7
		ctrl_command, "00000000", "00000001"   -- clear
	);

	-- cycle counters
	signal init_cycle, next_init_cycle : natural range 0 to init_num_commands := 0;
	signal cmd_byte_cycle, next_cmd_byte_cycle : natural range 0 to 4 := 0;
	signal write_cycle, next_write_cycle : integer range -3 to lcd_size := -3;

begin

	-- rising edge of serial bus ready signal
	bus_cycle <= in_bus_ready and not (bus_last_ready);


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
			write_cycle <= -3;
			cmd_byte_cycle <= 0;

			bus_last_ready <= '0';

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

			bus_last_ready <= in_bus_ready;
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(all)
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
				-- next command
				if bus_cycle = '1' then
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
							next_lcd_state <= Wait_UpdateDisplay;
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


			when Wait_UpdateDisplay =>
				wait_counter_max <= const_wait_UpdateDisplay;
				if wait_counter = wait_counter_max then
					next_lcd_state <= Pre_UpdateDisplay;
				end if;

				
			when Pre_UpdateDisplay =>
				if in_update = '1' then
					next_lcd_state <= UpdateDisplay;
				end if;


			when UpdateDisplay =>	
				-- next character
				if bus_cycle='1' then
					next_write_cycle <= write_cycle + 1;
				end if;

				-- write command or character
				case write_cycle is
					-- control byte for return
					when -3 =>
						out_bus_data <= ctrl_command;
						out_bus_enable <= '1';

					-- return: set display address to 0
					when -2 =>
						out_bus_data <= "10000000";
						out_bus_enable <= '1';

					-- control byte for data
					when -1 =>
						out_bus_data <= ctrl_data;
						out_bus_enable <= '1';

					-- sequence finished
					when static_lcd_size =>
						if in_bus_ready='1' then
							next_lcd_state <= Wait_UpdateDisplay;
							next_write_cycle <= -3;
						end if;

					-- read characters from display buffer
					when others =>
						-- write characters to lcd
						out_mem_addr <= int_to_logvec(
							write_cycle + mem_start_addr, lcd_num_addrbits);
						out_bus_data <= in_mem_word;
						out_bus_enable <= '1';
				end case;


			when others =>
				next_lcd_state <= Wait_Reset;
		end case;
	end process;

end architecture;
