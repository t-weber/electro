--
-- text lcd test
-- @author Tobias Weber
-- @date 27-jan-2024
-- @license see 'LICENSE' file
--
-- pins:
--              ○○
--              ○○
--              ○○
--              ○○
--              ○○
-- vss (blue)   ●● vdd 3.3V (red)
--              ○○
--              ...
--              ○● fpga sda_in  <- lcd sda_out (violet)
-- scl (green)  ●● fpga sda_out -> lcd sda_in (yellow)
-- rst (orange) ●○
--              ○○ gpio_0
--

library ieee;
use ieee.std_logic_1164.all;


entity main is
	generic(
		MAIN_CLK : natural := 50_000_000;
		SERIAL_CLK : natural := 1_000_000;

		WORDBITS : natural := 8;
		ADDRBITS : natural := 7;
		LCD_SIZE : natural := 4 * 20
	);

	port(
		-- main clock
		clock_50_b7a : in std_logic;

		-- lcd reset, serial clock and data lines (3-wire serial bus)
		lcd_reset, lcd_scl, lcd_sda : out std_logic;
		lcd_sda_in : in std_logic;

		ledr : out std_logic_vector(7 downto 0);
		ledg : out std_logic_vector(1 downto 0);
		key : in std_logic_vector(1 downto 0)
	);
end main;


architecture main_impl of main is
	signal reset, refresh : std_logic;

	signal ram_addr : std_logic_vector(ADDRBITS-1 downto 0);
	signal ram_read : std_logic_vector(WORDBITS-1 downto 0);

	signal serial_enable, serial_next, serial_ready : std_logic;
	signal serial_data : std_logic_vector(WORDBITS-1 downto 0);
	signal serial_data_in : std_logic_vector(WORDBITS-1 downto 0);

begin
	-- lcd memory
	disp_rom : entity work.rom
		generic map(NUM_PORTS => 1, NUM_WORDS => LCD_SIZE,
			WORDBITS => WORDBITS, ADDRBITS => ADDRBITS)
		port map(in_addr(0) => ram_addr, out_data(0) => ram_read);

	-- lcd
	lcd : entity work.txtlcd_3wire
		generic map(MAIN_CLK => MAIN_CLK, LCD_SIZE => LCD_SIZE)
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_update => refresh, in_bus_data => serial_data_in,
			in_bus_next => serial_next, in_bus_ready => serial_ready,
			out_bus_data => serial_data, out_bus_enable => serial_enable,
			in_mem_word => ram_read, out_mem_addr => ram_addr,
			out_busy_flag => ledr, out_lcd_reset => lcd_reset);

	-- serial bus for lcd
	serial_lcd : entity work.serial
		generic map(MAIN_HZ => MAIN_CLK, SERIAL_HZ => SERIAL_CLK,
			BITS => WORDBITS, LOWBIT_FIRST => '1')
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_enable => serial_enable, in_parallel => serial_data,
			out_next_word => serial_next, out_ready => serial_ready,
			out_clk => lcd_scl, out_serial => lcd_sda,
			in_serial => lcd_sda_in, out_parallel => serial_data_in);

	reset <= not key(0);
	refresh <= not key(1);

	--lcd_reset <= not reset;

	ledg(0) <= reset;
	ledg(1) <= refresh;

end main_impl;
