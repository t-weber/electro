--
-- float multiplier
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 11-June-2023
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.conv.all;


entity float_multiplier is
	generic(
		constant BITS : natural := 32;
		constant EXP_BITS : natural := 8;
		constant MANT_BITS : natural := 23 --BITS-EXP_BITS - 1
	);
	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- start signal
		in_start : in std_logic;

		-- inputs
		in_a, in_b : in std_logic_vector(BITS-1 downto 0);

		-- output
		out_prod : out std_logic_vector(BITS-1 downto 0);

		-- ready to calculate?
		out_ready : out std_logic
	);
end entity;


architecture float_multiplier_impl of float_multiplier is
	-- multiplier states
	type t_state is
	(
		Ready,      -- start multiplication
		Mult,       -- perform the multiplication
		Norm_Over,  -- normalise overflowing float
		Norm_Under  -- normalise underflowing float
	);

	signal state, state_next : t_state := Ready;

	-- current product value
	signal exp, exp_next : std_logic_vector(EXP_BITS-1 downto 0);
	signal mant, mant_next : std_logic_vector(MANT_BITS*2 downto 0);
begin


-- output product
out_prod <= (in_a(BITS-1) xor in_b(BITS-1)) & exp & mant(MANT_BITS-1 downto 0);
out_ready <= '1' when state = Ready else '0';


-- clock process with flip-flop
clk_proc : process(in_clk, in_rst) begin
	if in_rst = '1' then
		state <= Ready;
		exp <= (others => '0');
		mant <= (others => '0');
	elsif rising_edge(in_clk) then
		state <= state_next;
		exp <= exp_next;
		mant <= mant_next;
	end if;
end process;


-- calculation process combinatorics
calc_proc : process(all)
	variable a_full, b_full : std_logic_vector(MANT_BITS downto 0);
	variable mant_tmp : std_logic_vector(a_full'length+b_full'length-1 downto 0);

	constant EXP_BIAS : natural := 2**(EXP_BITS - 1) - 1;

	--constant MANT_1 : std_logic_vector(mant'high downto 0) := (MANT_BITS+1=>'1', others=>'0');
	constant MANT_1 : std_logic_vector(mant'high downto 0)
		:= (mant'high downto mant'high-MANT_BITS+2 =>'0') & '1' & (MANT_BITS downto 0 =>'0');
begin
	-- save registers
	state_next <= state;
	exp_next <= exp;
	mant_next <= mant;

	case state is
		when Ready =>
			-- wait for start signal
			if in_start then
				state_next <= Mult;
			end if;

		when Mult =>
			exp_next <= std_logic_vector(
				signed(in_a(BITS-2 downto BITS-1-EXP_BITS))
				+ signed(in_b(BITS-2 downto BITS-1-EXP_BITS))
				- to_signed(EXP_BIAS, EXP_BITS));

			a_full := '1' & in_a(MANT_BITS-1 downto 0);
			b_full := '1' & in_b(MANT_BITS-1 downto 0);
			mant_tmp := std_logic_vector(unsigned(a_full) * unsigned(b_full));
			mant_next <= (MANT_BITS-1 downto 0 => '0') & mant_tmp(mant'high downto MANT_BITS);

			state_next <= Norm_Over;

		when Norm_Over =>
			if mant >= MANT_1 then
				mant_next <= '0' & mant(mant'high downto 1);
				exp_next <= inc_logvec(exp, 1);
				state_next <= Norm_Over;
			else
				state_next <= Norm_Under;
			end if;

		when Norm_Under =>
			if unsigned(mant(MANT_BITS-1 downto 0)) /= 0 and mant(MANT_BITS) = '0' then
				mant_next <= mant(mant'high-1 downto 0) & '0';
				exp_next <= dec_logvec(exp, 1);
				state_next <= Norm_Under;
			else
				state_next <= Ready;
			end if;
	end case;
end process;

end;