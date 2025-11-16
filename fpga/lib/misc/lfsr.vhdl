--
-- pseudo-random numbers vis lfsr
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date jan-2021
-- @license see 'LICENSE' file
-- @see https://de.wikipedia.org/wiki/Linear_r%C3%BCckgekoppeltes_Schieberegister
--

library ieee;
use ieee.std_logic_1164.all;


entity lfsr is
	generic(
		-- number of bits for shift register
		constant BITS : natural := 8;

		-- initial seed
		constant SEED : std_logic_vector(BITS - 1 downto 0) :=
			(0 => '1', 2 => '1', others => '0');

		-- bits to xor
		constant FUNC : std_logic_vector(BITS - 1 downto 0) :=
			(1 => '1', 2 => '1', others => '0')
	);

	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- initial value
		in_seed : in std_logic_vector(BITS - 1 downto 0);

		-- enable setting of new seed
		in_setseed : in std_logic;

		-- get next value
		in_nextval : in std_logic;

		-- final value
		out_val : out std_logic_vector(BITS - 1 downto 0)
	);
end entity;



architecture lfsr_impl of lfsr is
	signal val : std_logic_vector(BITS - 1 downto 0) := SEED;


	function get_next_val(vec : std_logic_vector) return std_logic_vector is
		variable cur_bit : std_logic := '0';
	begin
		cur_bit := vec(0);

		for bit_idx in 0 to BITS - 1 loop
			if FUNC(bit_idx) = '1' then
				cur_bit := cur_bit xor vec(bit_idx);
			end if;
		end loop;

		return cur_bit & vec(BITS - 1 downto 1);
	end function;

begin
	-- output
	out_val <= val;


	process(in_clk) begin
		if rising_edge(in_clk) then
			if in_rst = '1' then
				-- reset to initial seed
				val <= SEED;
			elsif in_setseed = '1' then
				-- set new seed
				val <= in_seed;
			elsif in_nextval = '1' then
				-- next value
				val <= get_next_val(val);
			end if;
		end if;
	end process;
end architecture;
