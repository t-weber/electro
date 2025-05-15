--
-- clock divider
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2020
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;



entity clkdiv is
	generic
	(
		-- number of bits for counter
		constant NUM_CTRBITS : natural := 8;
		constant SHIFT_BITS : natural := 0;

		constant USE_RISING_EDGE : std_logic := '1'
	);

	port
	(
		in_clk, in_rst : in std_logic;
		out_clk : out std_logic
	);
end entity;



--
-- skips shift_bits clock cycles
--
architecture clkskip_impl of clkdiv is
	signal ctr, next_ctr : std_logic_vector(NUM_CTRBITS - 1 downto 0) := (others=>'0');
	signal ctr_fin : std_logic := '0';
	signal slow_clk, next_slow_clk : std_logic := '0';
begin
	-- output clock
	--out_clk <= slow_clk;
	out_clk <= in_clk when SHIFT_BITS = 1 else slow_clk;

	ctrprc_gen_if : if USE_RISING_EDGE = '1' generate
		ctrprc : process(in_clk, in_rst) begin
			if in_rst = '1' then
				ctr <= (others => '0');
				slow_clk <= '0';
			elsif rising_edge(in_clk) then
				ctr <= next_ctr;
				slow_clk <= next_slow_clk;
			end if;
		end process;
	end generate;
	ctrprc_gen_else : if USE_RISING_EDGE = '0' generate
		ctrprc : process(in_clk, in_rst) begin
			if in_rst = '1' then
				ctr <= (others => '0');
				slow_clk <= '0';
			elsif falling_edge(in_clk) then
				ctr <= next_ctr;
				slow_clk <= next_slow_clk;
			end if;
		end process;
	end generate;

	clkproc : process(ctr_fin) begin
		next_slow_clk <= slow_clk;

		--if ctr_fin'event and ctr_fin='1' then
		if rising_edge(ctr_fin) then
			next_slow_clk <= not slow_clk;
		end if;
	end process;

	-- count cycles to skip
	next_ctr <=
		int_to_logvec(0, NUM_CTRBITS)
			when ctr = nat_to_logvec(SHIFT_BITS - 1, NUM_CTRBITS)
		else inc_logvec(ctr, 1);

	ctr_fin <=
		'1' when ctr = nat_to_logvec(SHIFT_BITS - 1, NUM_CTRBITS)
		else '0';
end architecture;



--
-- standard behaviour:
-- divides clock by 2**shift_bits
--
architecture clkdiv_impl of clkdiv is
	signal ctr, next_ctr : std_logic_vector(NUM_CTRBITS - 1 downto 0) := (others=>'0');
begin

	ctrprc_gen_if : if USE_RISING_EDGE = '1' generate
		ctrprc : process(in_clk, in_rst) begin
			if in_rst = '1' then
				ctr <= (others => '0');
			elsif rising_edge(in_clk) then
				ctr <= next_ctr;
			end if;
		end process;
	end generate;
	ctrprc_gen_else : if USE_RISING_EDGE = '0' generate
		ctrprc : process(in_clk, in_rst) begin
			if in_rst = '1' then
				ctr <= (others => '0');
			elsif falling_edge(in_clk) then
				ctr <= next_ctr;
			end if;
		end process;
	end generate;

	next_ctr <= inc_logvec(ctr, 1);
	out_clk <= ctr(SHIFT_BITS);
end architecture;
