--
-- clock generation test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 17-may-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl ../clock/clkgen.vhdl ../clock/clkdiv.vhdl ../clock/clkctr.vhdl clocks_tb4.vhdl  &&  ghdl -e --std=08 clocks_tb4 clocks_tb4_arch
-- ghdl -r --std=08 clocks_tb4 clocks_tb4_arch --vcd=clocks_tb4.vcd --stop-time=1000ns
-- gtkwave clocks_tb4.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity clocks_tb4 is
end entity;


architecture clocks_tb4_arch of clocks_tb4 is
	constant VERBOSE : std_logic := '1';

	-- clocks
	constant FAST_CLK_DELAY : time := 20 ns;
	constant FAST_CLK_HZ : natural := 40_000_000;

	signal fast_clk, rst : std_logic := '0';
	signal slow_clk1a, slow_clk1b, slow_clk2 : std_logic := '0';

begin
	--
	-- fast main clock
	--
	fast_clk <= not fast_clk after FAST_CLK_DELAY;


	--
	-- generate the slow clocks
	--
	slow_clk1a_gen : entity work.clkdiv(clkdiv_impl)
		generic map(USE_RISING_EDGE => '1', NUM_CTRBITS => 3, SHIFT_BITS => 2)
		port map(in_clk => fast_clk, in_rst => rst, out_clk => slow_clk1a);
	slow_clk1b_gen : entity work.clkdiv(clkdiv_impl)
		generic map(USE_RISING_EDGE => '0', NUM_CTRBITS => 2, SHIFT_BITS => 1)
		port map(in_clk => slow_clk1a, in_rst => rst, out_clk => slow_clk1b);
	slow_clk2_gen : entity work.clkdiv(clkdiv_impl)
		generic map(USE_RISING_EDGE => '1', NUM_CTRBITS => 5, SHIFT_BITS => 4)
		port map(in_clk => fast_clk, in_rst => rst, out_clk => slow_clk2);

	--
	-- printing process
	--
	print_proc : process(fast_clk, rst)
	begin
		if VERBOSE = '1' then
			report	lf &
				"fast_clk = " & std_logic'image(fast_clk) &
				", slow_clk1a = " & std_logic'image(slow_clk1a) &
				", slow_clk1b = " & std_logic'image(slow_clk1b) &
				", slow_clk2 = " & std_logic'image(slow_clk2) &
				", reset: " & std_logic'image(rst);
		end if;
	end process;

end architecture;
