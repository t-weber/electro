--
-- floating point operations test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 18-June-2023
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity float_ops_test is
	port
	(
		clock : in std_logic;
		key : in std_logic_vector (0 downto 0);
		hex0, hex1, hex2, hex3 : out std_logic_vector(6 downto 0);
		ledr : out std_logic_vector(0 downto 0)
	);
end entity;


architecture float_ops_test_arch of float_ops_test is
	constant BITS : natural := 16;
	constant EXP_BITS : natural := 5;
	constant MANT_BITS : natural := BITS - EXP_BITS - 1;

	signal a, b, prod : std_logic_vector(BITS-1 downto 0);
begin
	a <= x"cc00";  -- -16
	b <= x"5640";  -- +100
	-- expected result: -1600 = 0xe640

	-- instantiate modules
	ops_ent : entity work.float_ops
		generic map(BITS => BITS, EXP_BITS => EXP_BITS, MANT_BITS => MANT_BITS)
		port map(in_clk => clock, in_rst => not key(0),
			in_start => '1', out_ready => ledr(0),
			in_op => "00",
			in_a => a, in_b => b, out_prod => prod);

	sevenseg1_ent : entity work.sevenseg
			generic map(zero_is_on => '1', inverse_numbering => '1')
			port map(in_digit => prod(3 downto 0), out_leds => hex0);
	sevenseg2_ent : entity work.sevenseg
			generic map(zero_is_on => '1', inverse_numbering => '1')
			port map(in_digit => prod(7 downto 4), out_leds => hex1);
	sevenseg3_ent : entity work.sevenseg
			generic map(zero_is_on => '1', inverse_numbering => '1')
			port map(in_digit => prod(11 downto 8), out_leds => hex2);
	sevenseg4_ent : entity work.sevenseg
			generic map(zero_is_on => '1', inverse_numbering => '1')
			port map(in_digit => prod(15 downto 12), out_leds => hex3);
end architecture;
