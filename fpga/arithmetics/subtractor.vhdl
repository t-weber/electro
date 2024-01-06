--
-- subtractor
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 13-May-2023
-- @license see 'LICENSE' file
--
-- Reference: https://en.wikipedia.org/wiki/Subtractor
--

library ieee;
use ieee.std_logic_1164.all;


entity subtractor is
	generic(
		-- selects full or half subtractor
		FULL_SUBTRACTOR : std_logic := '1'
	);
	port(
		in_a, in_b, in_borrow : in std_logic;
		out_diff, out_borrow : out std_logic
	);
end entity;


architecture subtractor_impl of subtractor is
	signal a_xor_b, not_a_and_b : std_logic;
begin
	a_xor_b <= in_a xor in_b;
	not_a_and_b <= (not in_a) and in_b;

	gen_fullsubtractor : if FULL_SUBTRACTOR='1' generate
		out_diff <= a_xor_b xor in_borrow;
		out_borrow <= not_a_and_b or
			(not in_a and in_borrow) or
			(in_b and in_borrow);
	end generate;

	gen_halfsubtractor : if FULL_SUBTRACTOR='0' generate
		out_diff <= a_xor_b;
		out_borrow <= not_a_and_b;
	end generate;
end architecture;




library ieee;
use ieee.std_logic_1164.all;


entity rippleborrowsubtractor is
	generic(
		constant BITS : natural := 16
	);
	port(
		in_a, in_b : in std_logic_vector(BITS-1 downto 0);
		out_diff : out std_logic_vector(BITS-1 downto 0)
	);
end entity;


architecture rippleborrowsubtractor_impl of rippleborrowsubtractor is
	signal borrow : std_logic_vector(BITS-1 downto 0);
begin
	subtractor_0 : entity work.subtractor
		generic map(FULL_SUBTRACTOR => '0')
		port map(in_a => in_a(0), in_b => in_b(0),
			in_borrow => '0',
			out_diff => out_diff(0),
			out_borrow => borrow(0));

	gen_subtractors : for subtractor_idx in 1 to BITS-1 generate
		subtractor_n : entity work.subtractor
			generic map(FULL_SUBTRACTOR => '1')
			port map(in_a => in_a(subtractor_idx),
				in_b => in_b(subtractor_idx),
				in_borrow => borrow(subtractor_idx - 1),
				out_diff => out_diff(subtractor_idx),
				out_borrow => borrow(subtractor_idx));
	end generate;
end architecture;
