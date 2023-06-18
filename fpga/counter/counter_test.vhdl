--
-- seven segment display test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date February-2022
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;



entity counter_test is
	port
	(
		-- input clock
		clock : in std_logic;

		-- reset key
		key : in std_logic_vector(0 downto 0);

		-- clock indicator
		ledr : out std_logic_vector(0 downto 0);

		-- output segment display
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0)
	);
end entity;



architecture counter_test_impl of counter_test is
	-- slow clock
	signal slow_clk : std_logic;

	-- current counter value
	signal count : std_logic_vector(15 downto 0);
	
begin
	-- clock indicator led
	ledr(0) <= slow_clk;

	-- slow clock
	slow_clk_ent : entity work.clkdiv(clkdiv_impl) 
		generic map(num_ctrbits => 26, shift_bits => 25)
		port map(in_rst => not key(0), in_clk => clock, out_clk => slow_clk);

	-- counter
	ctr_ent : entity work.counter
		generic map(num_ctrbits => 16)
		port map(in_rst => not key(0), in_clk => slow_clk, out_ctr => count);

	-- output segment display
	sevenseg1_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => count(3 downto 0), out_leds => hex0);
	sevenseg2_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => count(7 downto 4), out_leds => hex1);
	sevenseg3_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => count(11 downto 8), out_leds => hex2);
	sevenseg4_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => count(15 downto 12), out_leds => hex3);
end architecture;
