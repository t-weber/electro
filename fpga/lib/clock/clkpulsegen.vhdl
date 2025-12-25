--
-- generates a clock and timing pulses
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 23-dec-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;



entity clkpulsegen is
	generic(
		-- clock rates
		constant MAIN_HZ : natural := 50_000_000;
		constant CLK_HZ : natural := 10_000;

		-- reset value of clock
		constant CLK_INIT : std_logic := '0'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- output clock
		out_clk : out std_logic;

		-- output clock edges
		out_re, out_fe : out std_logic
	);
end entity;



architecture clkpulsegen_impl of clkpulsegen is
	-- generated clock
	signal clk : std_logic := CLK_INIT;
	-- edges pf generated clock
	signal re, fe : std_logic := '0';

begin
	-- output clock and edges
	out_clk <= clk;

	gen_edges : if CLK_INIT = '0' generate
		out_re <= re;
		out_fe <= fe;
	end generate;
	gen_edges_else : if CLK_INIT = '1' generate
		out_re <= fe;
		out_fe <= re;
	end generate;


	--
	-- generate clock
	--
	proc_clk : process(in_clk, in_reset)
		constant clk_ctr_half_max : natural := MAIN_HZ / CLK_HZ / 2;
		constant clk_ctr_full_max : natural := clk_ctr_half_max * 2;

		variable clk_ctr_half : natural range 0 to clk_ctr_half_max - 1 := 0;
		variable clk_ctr_full : natural range 0 to clk_ctr_full_max - 1 := 0;
	begin
		-- asynchronous reset
		if in_reset = '1' then
			clk_ctr_half := 0;
			clk <= CLK_INIT;

			re <= '0';
			fe <= '0';

		-- clock
		elsif rising_edge(in_clk) then
			if clk_ctr_half = clk_ctr_half_max - 1 then
				clk <= not clk;
				clk_ctr_half := 0;
			else
				clk_ctr_half := clk_ctr_half + 1;
			end if;

			re <= '0';
			fe <= '0'; 

			if clk_ctr_full = clk_ctr_half_max - 1 then
				re <= '1';
			elsif clk_ctr_full = clk_ctr_full_max - 1 then
				fe <= '1';
				clk_ctr_full := 0;
			else
				clk_ctr_full := clk_ctr_full + 1;
			end if;
		end if;
	end process;

end architecture;
