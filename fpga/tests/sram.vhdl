--
-- sram test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date February-2022
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;



entity sram_test is
	-- constants
	generic
	(
		constant ADDR_WIDTH : natural := 18;
		constant DATA_WIDTH : natural := 16
	);

	-- interface
	port
	(
		-- switches
		key : in std_logic_vector(3 downto 0);
		sw : in std_logic_vector(9 downto 0);
		
		-- sram
		sram_a : out std_logic_vector(ADDR_WIDTH-1 downto 0);
		sram_d : inout std_logic_vector(DATA_WIDTH-1 downto 0);
		sram_ub_n : out std_logic;
		sram_lb_n : out std_logic;
		sram_ce_n : out std_logic;
		sram_oe_n : out std_logic;
		sram_we_n : out std_logic;

		-- leds
		ledg : out std_logic_vector(7 downto 0);
		ledr : out std_logic_vector(9 downto 0);

		-- output segment display
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0)
	);
end entity;



architecture sram_test_impl of sram_test is
	signal addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal data : std_logic_vector(DATA_WIDTH-1 downto 0);

begin
	-- chip and byte enable signals
	sram_ub_n <= '0';
	sram_lb_n <= '0';
	sram_ce_n <= '0';

	-- read or write enable
	sram_oe_n <= not key(0);
	sram_we_n <= key(0);

	-- select address using switches
	sram_a <= addr;
	addr(ADDR_WIDTH-1 downto 10) <= (others => '0');
	addr(9 downto 0) <= sw;

	-- write sample data (0xabcd) when switch is pressed
	with key(0) select sram_d <= 
		x"abcd" when '0',
		(others=>'Z') when others;

	-- read when switch is not pressed
	with key(0) select data <= 
		sram_d when '1',
		(others=>'0') when others;
	
	ledg(7 downto 1) <= (others => '0');
	ledg(0) <= key(0);
	ledr <= sw;

	-- output data at current address
	sevenseg_data0 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => data(3 downto 0), out_leds => hex0);
	sevenseg_data1 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => data(7 downto 4), out_leds => hex1);
	sevenseg_data2 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => data(11 downto 8), out_leds => hex2);
	sevenseg_data3 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => data(15 downto 12), out_leds => hex3);
end architecture;
