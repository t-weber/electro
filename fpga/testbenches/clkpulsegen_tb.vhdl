--
-- clock generator testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 -fpsl ../lib/conv/conv.vhdl ../lib/clock/clkpulsegen.vhdl clkpulsegen_tb.vhdl  &&  ghdl -e --std=08 -fpsl clkpulsegen_tb clkpulsegen_tb_arch
-- ghdl -r --std=08 -fpsl clkpulsegen_tb clkpulsegen_tb_arch --vcd=clkpulsegen_tb.vcd --stop-time=500ns
-- gtkwave clkpulsegen_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity clkpulsegen_tb is
end entity;


architecture clkpulsegen_tb_arch of clkpulsegen_tb is
	constant VERBOSE : std_logic := '1';

	-- clocks
	constant MAIN_CLK_HZ : natural := 40_000_000;
	constant SLOW_CLK_HZ : natural := 10_000_000;
	constant MAIN_CLK_DELAY : time := 20 ns;
	constant RESET_DELAY : time := 40 ns;

	signal main_clk, slow_clk : std_logic := '0';
	signal rst : std_logic := '0';

begin
	--
	-- fast main clock
	--
	main_clk <= not main_clk after MAIN_CLK_DELAY;


	--
	-- init process
	--
	init_proc : process begin
		rst <= '1';
		wait for RESET_DELAY;
		rst <= '0';

		wait;
	end process;


	--
	-- generate slow clock
	--
	slow_clk_gen : entity work.clkpulsegen
		generic map(MAIN_HZ => MAIN_CLK_HZ, CLK_HZ => SLOW_CLK_HZ,
			CLK_INIT => '0')
		port map(in_clk => main_clk, in_reset => rst, out_clk => slow_clk);

end architecture;
