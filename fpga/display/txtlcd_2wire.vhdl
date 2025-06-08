--
-- text lc display using serial 2-wire bus protocol and a fixed init sequence
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2020, nov-2023
-- @license see 'LICENSE' file
--
-- references for lcd:
--   - [lcd] https://www.lcd-module.de/fileadmin/pdf/doma/dogm204.pdf
--   - [ic]  https://www.lcd-module.de/fileadmin/eng/pdf/zubehoer/ssd1803a_2_0.pdf
-- reference for serial bus usage:
--   - https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324
--
-- note: serial data and clock signal need to be declared 3-state (high-Z for idle state)
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity txtlcd_2wire is
	generic(
		-- clock
		constant MAIN_CLK : natural := 50_000_000;

		-- word length and address of the LCD
		constant BUS_NUM_ADDRBITS : natural := 8;
		constant BUS_NUM_DATABITS : natural := 8;
		constant BUS_WRITEADDR : std_logic_vector(BUS_NUM_ADDRBITS - 1 downto 0) := x"10";

		-- number of characters on the LCD
		constant LCD_SIZE : natural := 4 * 20;
		constant LCD_NUM_ADDRBITS : natural := 7;
		constant LCD_NUM_DATABITS : natural := BUS_NUM_DATABITS;

		-- start address of the display buffer in the memory
		constant MEM_START_ADDR : natural := 0
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- reset for LCD
		out_lcd_reset : out std_logic;

		-- update the display
		in_update : in std_logic;

		-- serial bus interface
		in_bus_busy, in_bus_error : in std_logic;
		out_bus_enable : out std_logic;
		out_bus_addr : out std_logic_vector(BUS_NUM_ADDRBITS - 1 downto 0);
		out_bus_data : out std_logic_vector(BUS_NUM_DATABITS - 1 downto 0);

		-- display buffer
		in_mem_word : in std_logic_vector(LCD_NUM_DATABITS - 1 downto 0);
		out_mem_addr : out std_logic_vector(LCD_NUM_ADDRBITS - 1 downto 0)
	);
end entity;



architecture txtlcd_2wire_impl of txtlcd_2wire is
	-- states
	type t_lcd_state is (
		Wait_Reset, Reset, Resetted,
		ReadInitSeq,
		Wait_UpdateDisplay, Pre_UpdateDisplay, UpdateDisplay);
	signal lcd_state, next_lcd_state : t_lcd_state;
	signal bus_last_busy, bus_cycle : std_logic;

	-- delays
	constant const_wait_prereset : natural := MAIN_CLK/1000*50;        -- 50 ms
	constant const_wait_reset : natural := MAIN_CLK/1000_000*500;      -- 500 us
	constant const_wait_resetted : natural := MAIN_CLK/1000*1;         -- 1 ms
	constant const_wait_UpdateDisplay : natural := MAIN_CLK/1000*200;  -- 200 ms

	-- the maximum of the above delays
	constant const_wait_max : natural := const_wait_UpdateDisplay;

	-- busy wait counters
	signal wait_counter, wait_counter_max : natural range 0 to const_wait_max := 0;

	-- lcd with 4-lines and 20 characters per line
	constant static_lcd_size : natural := 4 * 20; --LCD_SIZE;

	--
	-- lcd init commands
	-- see p. 5 in [lcd] and pp. 38-40 in [ic]
	--
	-- control bytes
	constant ctrl_data            : std_logic_vector(BUS_NUM_DATABITS - 1 downto 0) := "01000000";
	constant ctrl_command         : std_logic_vector(BUS_NUM_DATABITS - 1 downto 0) := "10000000";
	constant ctrl_command_datareg : std_logic_vector(BUS_NUM_DATABITS - 1 downto 0) := "11000000";

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
	type t_init_arr is array(0 to init_num_commands*2 - 1)
		of std_logic_vector(LCD_NUM_DATABITS - 1 downto 0);
	constant init_arr : t_init_arr := (
		-- power, [ic, p. 38]
		ctrl_command, "001" & use_8bits & use_4lines & fontheight_on & '1' & '1',  -- re=1, is=1
		ctrl_command, "00000010",  -- no sleep

		-- scrolling or shifting, [ic, pp. 39-40]
		ctrl_command, "000001" & mirror_y & mirror_x,
		ctrl_command, "00001" & use_longfont & invert_caret & use_4lines,
		ctrl_command, std_logic_vector'("0001" & shift_lines),
		ctrl_command, std_logic_vector'("11" & scroll),

		-- rom selection, [ic, p. 40]
		ctrl_command, "01110010",
		ctrl_command_datareg, std_logic_vector'("0000" & char_rom & "00"),

		-- select temperature, [ic, p. 40]
		ctrl_command, "01110110",
		ctrl_command_datareg, std_logic_vector'("00000" & temperature),

		-- voltage divider, [ic, pp. 39-40]
		ctrl_command, "001" & use_8bits & use_4lines & fontheight_on & '1' & '0',  -- re=1, is=0
		ctrl_command, "0001" & double_height & divider_bias(1) & shift_on,

		-- voltage divider, [ic, pp. 39-40]
		ctrl_command, "001" & use_8bits & use_4lines & fontheight_on & '0' & '1',  -- re=0, is=1
		ctrl_command, std_logic_vector'("0001" & divider_bias(0) & oscillator),
		ctrl_command, std_logic_vector'("01010" & booster_on & contrast(5 downto 4)),
		ctrl_command, std_logic_vector'("0111" & contrast(3 downto 0)),
		ctrl_command, std_logic_vector'("0110" & divider_on & divider_ratio),

		-- scrolling or shifting [ic, p. 38]
		ctrl_command, "001" & use_8bits & use_4lines & fontheight_on & '0' & '0',  -- re=0, is=0
		ctrl_command, "000001" & caret_right & shift_disp_on,

		-- turn on display, [ic, p. 38]
		ctrl_command, "000011" & caret_on & blink_on,

		--ctrl_command, "01000000",  -- character ram address
		--ctrl_command_datareg, "00011111",  -- define character 0 line 0
		--ctrl_command_datareg, "00011011",  -- define character 0 line 1
		--ctrl_command_datareg, "00010001",  -- define character 0 line 2
		--ctrl_command_datareg, "00010001",  -- define character 0 line 3
		--ctrl_command_datareg, "00010001",  -- define character 0 line 4
		--ctrl_command_datareg, "00010001",  -- define character 0 line 5
		--ctrl_command_datareg, "00010001",  -- define character 0 line 6
		--ctrl_command_datareg, "00000000",  -- define character 0 line 7

		-- clear and return, [ic, p. 38]
		ctrl_command, "00000001",
		ctrl_command, "00000010"
	);

	-- cycle counters
	signal init_cycle, next_init_cycle : natural range 0 to init_arr'length := 0;
	signal write_cycle, next_write_cycle : integer range -3 to LCD_SIZE := -3;

begin

	-- rising edge of serial bus busy signal
	bus_cycle <= in_bus_busy and (not bus_last_busy);


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
		out_bus_addr <= BUS_WRITEADDR;
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
					next_init_cycle <= init_cycle + 1;
				end if;

				case init_cycle is
					-- sequence finished
					--when init_arr'length =>
					when init_num_commands*2 =>
						if in_bus_busy = '0' then
							next_lcd_state <= Wait_UpdateDisplay;
							next_init_cycle <= 0;
						end if;

					-- read init sequence
					when others =>
						-- error occured -> retransmit everything
						if in_bus_error = '1' then
							if in_bus_busy = '0' then
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
				if bus_cycle = '1' then
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
						if in_bus_busy = '0' then
							next_lcd_state <= Wait_UpdateDisplay;
							next_write_cycle <= -3;
						end if;

					-- read characters from display buffer
					when others =>
						-- error occured -> retransmit everything
						if in_bus_error = '1' then
							if in_bus_busy = '0' then
								next_lcd_state <= UpdateDisplay;
								next_write_cycle <= -3;
							end if;

						-- write characters to lcd
						else
							out_mem_addr <= int_to_logvec(
								write_cycle + MEM_START_ADDR, LCD_NUM_ADDRBITS);
							out_bus_data <= in_mem_word;
							out_bus_enable <= '1';
						end if;
				end case;


			when others =>
				next_lcd_state <= Wait_Reset;
		end case;
	end process;

end architecture;
