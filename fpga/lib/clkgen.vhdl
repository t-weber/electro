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
		constant CLK_INIT : std_logic := '0'
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

begin
	-- output clock
	out_clk <= clk;


	--
	-- generate clock
	--
	proc_clk : process(in_clk, in_reset)
		constant clk_ctr_max : natural := MAIN_HZ / CLK_HZ / 2 - 1;
		variable clk_ctr : natural range 0 to clk_ctr_max := 0;
	begin
		-- asynchronous reset
		if in_reset = '1' then
			clk_ctr := 0;
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

end architecture;
