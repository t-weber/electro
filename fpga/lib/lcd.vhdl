--
-- LC display via serial 2- or 4-wire bus (using a fixed init sequence)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2020, nov-2023
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


entity lcd is
	generic(
		-- clock
		constant main_clk : natural := 50_000_000;

		-- word length and address of the LCD
		constant bus_num_addrbits : natural := 8;
		constant bus_num_databits : natural := 8;
		constant bus_writeaddr : std_logic_vector(bus_num_addrbits-1 downto 0) := x"10";

		-- number of characters on the LCD
		constant lcd_size : natural := 4*20;
		constant lcd_num_addrbits : natural := 7;
		constant lcd_num_databits : natural := bus_num_databits;

		-- start address of the display buffer in the memory
		constant mem_start_addr : natural := 0
	);

	port(
		-- main clock
		in_clk : in std_logic;

		-- reset
		in_reset : in std_logic;
		-- reset for LCD
		out_lcd_reset : out std_logic;
		
		-- update the display
		in_update : in std_logic;

		-- serial bus interface
		in_bus_busy, in_bus_error : in std_logic;
		out_bus_enable : out std_logic;
		out_bus_addr : out std_logic_vector(bus_num_addrbits-1 downto 0);
		out_bus_data : out std_logic_vector(bus_num_databits-1 downto 0);

		-- display buffer
		out_mem_addr : out std_logic_vector(lcd_num_addrbits-1 downto 0);
		in_mem_word : in std_logic_vector(lcd_num_databits-1 downto 0)
	);
end entity;



architecture lcd_impl of lcd is
	-- states
	type t_lcd_state is (
		Wait_Reset, Reset, Resetted,
		ReadInitSeq,
		Wait_UpdateDisplay, Pre_UpdateDisplay, UpdateDisplay);
	signal lcd_state, next_lcd_state : t_lcd_state;
	signal bus_last_busy, bus_cycle : std_logic;

	-- delays
	constant const_wait_prereset : natural := main_clk/1000*50;        -- 50 ms
	constant const_wait_reset : natural := main_clk/1000_000*500;      -- 500 us
	constant const_wait_resetted : natural := main_clk/1000*1;         -- 1 ms
	constant const_wait_UpdateDisplay : natural := main_clk/1000*200;  -- 200 ms

	-- the maximum of the above delays
	constant const_wait_max : natural := const_wait_UpdateDisplay;

	-- busy wait counters
	signal wait_counter, wait_counter_max : natural range 0 to const_wait_max := 0;

	-- lcd with 4-lines and 20 characters per line
	constant static_lcd_size : natural := 4 * 20;

	-- control bytes
	constant ctrl_data : std_logic_vector(bus_num_databits-1 downto 0) := "01000000";
	constant ctrl_command : std_logic_vector(bus_num_databits-1 downto 0) := "10000000";
	constant ctrl_command_datareg : std_logic_vector(bus_num_databits-1 downto 0) := "11000000";

	-- lcd init commands
	-- see p. 5 in https://www.lcd-module.de/fileadmin/pdf/doma/dogm204.pdf
	type t_init_arr is array(0 to 21*2 - 1) of std_logic_vector(lcd_num_databits-1 downto 0);
	constant init_arr : t_init_arr := (
		ctrl_command, "00111011",  -- 8 bit, 4 lines, normal font size, re=1, is=1
		ctrl_command, "00000010",  -- no sleep
		ctrl_command, "00000110",  -- shift direction (mirror view)
		ctrl_command, "00001001",  -- short font width, no caret inversion, 4 lines
		ctrl_command, "00010000",  -- scroll (or shift) off for lines 3-0
		ctrl_command, "11000000",  -- scroll amount
		ctrl_command, "01110010",  -- select rom
		ctrl_command_datareg, "00000000",  -- first rom
		--ctrl_command_datareg, "00000100",  -- second rom
		--ctrl_command_datareg, "00001000",  -- third rom
		ctrl_command, "01110110",  -- select temperature control
		ctrl_command_datareg, "00000010",  -- temperature

		ctrl_command, "00111010",  -- 8 bit, 4 lines, normal font size, re=1, is=0
		ctrl_command, "00010010",  -- 2 double-height bits, voltage divider bias bit 1, shift off (scroll on)

		ctrl_command, "00111001",  -- 8 bit, 4 lines, no blinking, no reversing, re=0, is=1
		ctrl_command, "00011011",  -- voltage divider bias bit 0, oscillator bits 2-0
		ctrl_command, "01010111",  -- no icon, voltage regulator, contrast bits 5 and 4
		ctrl_command, "01110000",  -- contrast bits 3-0
		ctrl_command, "01101110",  -- voltage divider, amplifier bits 2-0
		
		ctrl_command, "00111000",  -- 8 bit, 4 lines, no blinking, no reversing, re=0, is=0
		ctrl_command, "00000110",  -- caret moving right, no display shifting
		ctrl_command, "00001100",  -- turn on display, no caret, no blinking
		--ctrl_command, "01000000",  -- character ram address
		--ctrl_command_datareg, "00011111",  -- define character 0 line 0
		--ctrl_command_datareg, "00011011",  -- define character 0 line 1
		--ctrl_command_datareg, "00010001",  -- define character 0 line 2
		--ctrl_command_datareg, "00010001",  -- define character 0 line 3
		--ctrl_command_datareg, "00010001",  -- define character 0 line 4
		--ctrl_command_datareg, "00010001",  -- define character 0 line 5
		--ctrl_command_datareg, "00010001",  -- define character 0 line 6
		--ctrl_command_datareg, "00000000",  -- define character 0 line 7
		ctrl_command, "00000001"   -- clear
	);

	-- cycle counters
	signal init_cycle, next_init_cycle : natural range 0 to init_arr'length := 0;
	signal write_cycle, next_write_cycle : integer range -3 to lcd_size := -3;

begin

	-- rising edge of serial bus busy signal
	bus_cycle <= in_bus_busy and (not bus_last_busy);


	--
	-- flip-flops
	--
	proc_ff : process(in_clk, in_reset) begin
		-- reset
		if in_reset = '0' then
			-- state register
			lcd_state <= Wait_Reset;
			
			-- timer register
			wait_counter <= 0;

			-- counter registers
			init_cycle <= 0;
			write_cycle <= -3;

			bus_last_busy <= '0';

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

			bus_last_busy <= in_bus_busy;
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(
		in_update, wait_counter, wait_counter_max,
		lcd_state, bus_cycle, init_cycle, write_cycle, 
		in_mem_word, in_bus_busy, in_bus_error)
	begin
		-- defaults
		next_lcd_state <= lcd_state;
	
		next_init_cycle <= init_cycle;
		next_write_cycle <= write_cycle;
		
		wait_counter_max <= 0;

		out_lcd_reset <= '1';
		out_mem_addr <= (others => '0');

		out_bus_enable <= '0';
		out_bus_addr <= bus_writeaddr;
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
				if bus_cycle='1' then
					next_init_cycle <= init_cycle + 1;
				end if;

				case init_cycle is
					-- sequence finished
					when init_arr'length =>
						if in_bus_busy='0' then
							next_lcd_state <= Wait_UpdateDisplay;
							next_init_cycle <= 0;
						end if;

					-- read init sequence
					when others =>
						-- error occured -> retransmit everything
						if in_bus_error='1' then
							if in_bus_busy='0' then
								next_lcd_state <= ReadInitSeq;
								next_init_cycle <= 0;
							end if;
						-- write sequence commands to lcd
						else
							out_bus_data <= init_arr(init_cycle);
							out_bus_enable <= '1';
						end if;
				end case;


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
						if in_bus_busy='0' then
							next_lcd_state <= Wait_UpdateDisplay;
							next_write_cycle <= -3;
						end if;

					-- read characters from display buffer
					when others =>
						-- error occured -> retransmit everything
						if in_bus_error='1' then
							if in_bus_busy='0' then
								next_lcd_state <= UpdateDisplay;
								next_write_cycle <= -3;
							end if;
								
						-- write characters to lcd
						else
							out_mem_addr <= int_to_logvec(
								write_cycle + mem_start_addr, lcd_num_addrbits);
							out_bus_data <= in_mem_word;
							out_bus_enable <= '1';
						end if;
				end case;


			when others =>
				next_lcd_state <= Wait_Reset;
		end case;
	end process;

end architecture;
