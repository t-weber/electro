--
-- adder
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 30-April-2023
-- @license see 'LICENSE' file
--
-- Reference: https://en.wikipedia.org/wiki/Adder_(electronics)
--

library ieee;
use ieee.std_logic_1164.all;


entity adder is
	generic(
		-- selects full or half adder
		FULL_ADDER : std_logic := '1'
	);
	port(
		in_a, in_b, in_carry : in std_logic;
		out_sum, out_carry : out std_logic
	);
end entity;


architecture adder_impl of adder is
	signal a_xor_b, a_and_b, x_and_c : std_logic;
begin
	a_xor_b <= in_a xor in_b;
	a_and_b <= in_a and in_b;

	gen_fulladder : if FULL_ADDER='1' generate
		x_and_c <= a_xor_b and in_carry;

		out_sum <= a_xor_b xor in_carry;
		out_carry <= a_and_b or x_and_c;
	end generate;

	gen_halfadder : if FULL_ADDER='0' generate
		out_sum <= a_xor_b;
		out_carry <= a_and_b;
	end generate;
end architecture;



library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;

entity ripplecarryadder is
	generic(
		constant BITS : natural := 16
	);
	port(
		in_a, in_b : in std_logic_vector(BITS-1 downto 0);
		out_sum : out std_logic_vector(BITS-1 downto 0)
	);
end entity;


architecture ripplecarryadder_impl of ripplecarryadder is
	signal carry : std_logic_vector(BITS-1 downto 0);
begin
	adder_0 : entity work.adder
		generic map(FULL_ADDER => '0')
		port map(in_a => in_a(0), in_b => in_b(0),
			in_carry => '0',
			out_sum => out_sum(0), out_carry => carry(0));

	gen_adders : for adder_idx in 1 to BITS-1 generate
		adder_n : entity work.adder
			generic map(FULL_ADDER => '1')
			port map(in_a => in_a(adder_idx),
				in_b => in_b(adder_idx),
				in_carry => carry(adder_idx - 1),
				out_sum => out_sum(adder_idx),
				out_carry => carry(adder_idx));
	end generate;
end architecture;
