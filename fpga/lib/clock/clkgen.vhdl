--
-- generates a (slower) clock
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-nov-2023
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;



entity clkgen is
	generic(
		-- clock rates
		constant MAIN_HZ : natural := 50_000_000;
		constant CLK_HZ : natural := 10_000;

		-- reset value of clock
		constant CLK_INIT : std_logic := '0';
		constant CLK_SHIFT : std_logic := '0'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- output clock
		out_clk : out std_logic
	);
end entity;



architecture clkgen_impl of clkgen is
	-- generated clock
	signal clk : std_logic := CLK_INIT;

	pure function get_clk_shift(is_shifted : std_logic) return natural is
		variable shifted_clk : natural := 0;
	begin
		if is_shifted = '1' then
			shifted_clk := MAIN_HZ / CLK_HZ / 2 - MAIN_HZ / CLK_HZ / 4;
		else
			shifted_clk := 0;
		end if;

		return shifted_clk;
	end function;

begin
	-- output clock
	gen_clk : if MAIN_HZ = CLK_HZ generate

		gen_shift : if CLK_SHIFT = '1' and CLK_INIT = '0' generate
			-- same frequency, just output main clock
			out_clk <= in_clk;
		elsif CLK_SHIFT = '0' and CLK_INIT = '1' generate
			-- same frequency, just output main clock
			out_clk <= in_clk;
		else generate
			-- same frequency, but inverted

			-- avoid gating the clock as this causes glitches
			--out_clk <= not in_clk;
			out_clk <= clk;

			-- output a signal from a flip-flop instead of a gate
			process(in_clk, in_reset) begin
				if in_reset = '1' then
					clk <= CLK_INIT;
				--elsif rising_edge(in_clk) then
				else
					clk <= not clk;
				end if;
			end process;

		-- psl inv_clk_assert : assert always (in_clk and not in_reset -> clk) @rising_edge(in_clk);
		end generate;

	else generate

		-- output slower clock
		out_clk <= clk;

		--
		-- generate clock
		--
		proc_clk : process(in_clk, in_reset)
			constant clk_ctr_max : natural := MAIN_HZ / CLK_HZ / 2 - 1;
			constant clk_ctr_shifted : natural := get_clk_shift(is_shifted => CLK_SHIFT);
			variable clk_ctr : natural range 0 to clk_ctr_max := 0;
		begin
			--report "ref_clk = " & natural'image(MAIN_HZ) & " Hz"
			--	& ", req_clk = " & natural'image(CLK_HZ) & " Hz"
			--	& ", gen_clk = " & natural'image(MAIN_HZ / (clk_ctr_max*2 + 2)) & " Hz"
			--	& ", clk_ctr_max = " & natural'image(clk_ctr_max)
			--	& ", clk_ctr_shifted = " & natural'image(clk_ctr_shifted);

			-- asynchronous reset
			if in_reset = '1' then
				clk_ctr := clk_ctr_shifted;
				clk <= CLK_INIT;

			-- clock
			elsif rising_edge(in_clk) then
				if clk_ctr = clk_ctr_max then
					clk <= not clk;
					clk_ctr := 0;
				else
					clk_ctr := clk_ctr + 1;
				end if;
			end if;
		end process;
	end generate;

end architecture;
