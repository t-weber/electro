--
-- divider
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 7-January-2024
-- @license see 'LICENSE' file
--


library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
use work.conv.all;


entity divider is
	generic(
		constant BITS : natural := 8
	);
	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- start signal
		in_start : in std_logic;

		-- input dividend and divisor
		in_a, in_b : in std_logic_vector(BITS-1 downto 0);

		-- output quotient and remainder
		out_quot, out_rem : out std_logic_vector(BITS-1 downto 0);

		-- calculation finished?
		out_finished : out std_logic
	);
end entity;



--
-- division by successive subtraction (i.e. addition of 2s complement)
-- TODO: create more efficient implementation
--
architecture divider_impl of divider is
	-- divider states
	type t_state is
	(
		Reset,      -- start division
		CheckSub,   -- check if a subtraction is possible
		Sub,        -- subtract divisor
		Finished    -- division finished
	);

	signal state, state_next : t_state := Reset;

	-- quotient and remainder
	signal quotient, quotient_next : std_logic_vector(BITS-1 downto 0);
	signal remainder, remainder_next : std_logic_vector(BITS-1 downto 0);

	signal b_2scomp : std_logic_vector(BITS-1 downto 0);

	-- use adder module
	signal remainder_sub : std_logic_vector(BITS-1 downto 0);
begin


-- use adder module
-- add shifted b value to current product value
adder : entity work.ripplecarryadder
        generic map(BITS => BITS)
        port map(in_a => remainder, in_b => b_2scomp, out_sum => remainder_sub);


-- 2s complement of the divisor, in_b
b_2scomp <= int_to_logvec(to_int(not in_b) + 1, BITS);


-- output signals
out_quot <= quotient;
out_rem <= remainder;
out_finished <= '1' when state = Finished else '0';


-- clock process
clk_proc : process(in_clk, in_rst) begin
	if in_rst = '1' then
		state <= Reset;
		quotient <= (others => '0');
		remainder <= (others => '0');
	elsif rising_edge(in_clk) then
		state <= state_next;
		quotient <= quotient_next;
		remainder <= remainder_next;
	end if;
end process;


-- calculation process
calc_proc : process(all) begin
	-- save registers
	state_next <= state;
	quotient_next <= quotient;
	remainder_next <= remainder;

	case state is
		-- set remainder := dividend
		when Reset =>
			quotient_next <= (others => '0');
			remainder_next <= in_a;
			state_next <= CheckSub;

		-- check if the divisor can be subtracted from the remainder
		when CheckSub =>
			if to_int(remainder) >= to_int(in_b) then
				state_next <= Sub;
			else
				state_next <= Finished;
			end if;
		
		-- subtract the divisor from the remainder
		when Sub =>
			-- use internal adder
			--remainder_next <= int_to_logvec(
			--	to_int(remainder) + to_int(b_2scomp), BITS);

			-- alternatively use internal subtractor
			--remainder_next <= int_to_logvec(
			--	to_int(remainder) - to_int(in_b), BITS);

			-- alternatively use adder module
			remainder_next <= remainder_sub;

			quotient_next <= inc_logvec(quotient, 1);
			state_next <= CheckSub;

		when Finished =>
			-- wait for start signal
			if in_start then
				state_next <= Reset;
			end if;
	end case;
end process;

end;
