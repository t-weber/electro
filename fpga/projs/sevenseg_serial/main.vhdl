--
-- serial seven segment display test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-dec-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity main is
	port(
		-- main clock
		clk27 : in std_logic;

		-- seven segment display
		sevenseg_clk : inout std_logic;
		sevenseg_dat : inout std_logic;

		-- buttons and leds
		key : in std_logic_vector(1 downto 0);
		led : out std_logic_vector(2 downto 0);
		ledr : out std_logic_vector(7 downto 0)
	);
end entity;


architecture main_impl of main is
	constant MAIN_CLK   : natural := 27_000_000;
	constant SERIAL_CLK : natural :=     5; --10_000;

	constant SERIAL_BITS : natural := 8;
	constant NUM_SEGS    : natural := 4;

	signal rst : std_logic := '0';

	-- seven segment serial bus
	signal serial_enable : std_logic := '1';
	signal serial_ready, serial_err, serial_next_word : std_logic;
	signal serial_in_parallel : std_logic_vector(SERIAL_BITS - 1 downto 0);

	-- seven segment module
	signal stop_update : std_logic;
	signal displayed_ctr : std_logic_vector(NUM_SEGS*4 - 1 downto 0) := (others => '0');
begin

--------------------------------------------------------------------------------
-- keys
--------------------------------------------------------------------------------
debounce_key0 : entity work.debounce(debounce_switch_impl)
	port map(in_clk => clk27, in_rst => '0', in_signal => not key(0), out_debounced => rst);

debounce_key1 : entity work.debounce(debounce_button_impl)
	port map(in_clk => clk27, in_rst => rst, in_signal => not key(1), out_toggled => stop_update);
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- seven segment serial bus
--------------------------------------------------------------------------------
serial_mod : entity work.serial_2wire
	generic map(MAIN_HZ => MAIN_CLK, SERIAL_HZ => SERIAL_CLK,
		BITS => SERIAL_BITS, LOWBIT_FIRST => '1', ADDR_BITS => 1,
		TRANSMIT_ADDR => '0', IGNORE_ERROR => '0')
	port map(in_clk => clk27, in_reset => rst,
		in_enable => serial_enable, in_write => '1',
		in_addr_write => (others => '0'), in_addr_read => (others => '0'),
		in_parallel => serial_in_parallel, out_parallel => open,
		out_ready => serial_ready, out_err => serial_err,
		out_next_word => serial_next_word,
		inout_clk => sevenseg_clk, inout_serial => sevenseg_dat);
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- seven segment module
--------------------------------------------------------------------------------
sevenseg_mod : entity work.sevenseg_serial
	generic map(MAIN_CLK => MAIN_CLK, BUS_BITS => SERIAL_BITS, NUM_SEGS => NUM_SEGS)
	port map(in_clk => clk27, in_rst => rst,
		in_update => not stop_update, in_digits => displayed_ctr,
		in_bus_ready => serial_ready, in_bus_next_word => serial_next_word,
		out_bus_enable => serial_enable, out_bus_data => serial_in_parallel);
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
-- leds
--------------------------------------------------------------------------------
led <= (0 => not serial_err, 1 => '1', 2 => not serial_ready);
ledr <= (0 => stop_update, 1 => sevenseg_clk, 2 => sevenseg_dat, others => '0');
--------------------------------------------------------------------------------

end architecture;
