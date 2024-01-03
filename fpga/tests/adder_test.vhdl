--
-- adder test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 30-apr-2023
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;


entity adder_top is
	port
	(
		hex0, hex1, hex2, hex3 : out std_logic_vector(6 downto 0)
	);
end entity;


architecture adder_top_arch of adder_top is
	constant BITS : natural := 16;

	signal a, b : std_logic_vector(BITS-1 downto 0) := (others => '0');
	signal sum : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin

	a <= x"1212";
	b <= x"2121";

	adder_ent : entity work.ripplecarryadder
		 generic map(BITS => BITS)
		 port map(in_a => a, in_b => b, out_sum => sum);
		 
	sevenseg1_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => sum(3 downto 0), out_leds => hex0);
	sevenseg2_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => sum(7 downto 4), out_leds => hex1);
	sevenseg3_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => sum(11 downto 8), out_leds => hex2);
	sevenseg4_ent : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => sum(15 downto 12), out_leds => hex3);

end architecture;
