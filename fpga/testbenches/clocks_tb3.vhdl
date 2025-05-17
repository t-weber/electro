--
-- clock generation test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 17-may-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl ../clock/clkgen.vhdl ../clock/clkdiv.vhdl ../clock/clkctr.vhdl clocks_tb3.vhdl  &&  ghdl -e --std=08 clocks_tb3 clocks_tb3_arch
-- ghdl -r --std=08 clocks_tb3 clocks_tb3_arch --vcd=clocks_tb3.vcd --stop-time=500ns
-- gtkwave clocks_tb3.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity clocks_tb3 is
end entity;


architecture clocks_tb3_arch of clocks_tb3 is
	constant VERBOSE : std_logic := '1';

	-- clocks
	constant FAST_CLK_DELAY : time := 20 ns;
	constant FAST_CLK_HZ : natural := 40_000_000;
	constant SLOW_CLK_HZ : natural := 5_000_000;

	signal fast_clk, rst : std_logic := '0';
	signal slow_clk1, slow_clk2, slow_clk3 : std_logic := '0';

begin
	--
	-- fast main clock
	--
	fast_clk <= not fast_clk after FAST_CLK_DELAY;


	--
	-- generate the slow clock in three different ways
	--
	slow_clk1_gen : entity work.clkgen
		generic map(MAIN_HZ => FAST_CLK_HZ, CLK_HZ => SLOW_CLK_HZ, CLK_INIT => '0')
		port map(in_clk => fast_clk, in_reset => rst, out_clk => slow_clk1);

	slow_clk2_gen : entity work.clkdiv(clkdiv_impl)
		generic map(USE_RISING_EDGE => '1', NUM_CTRBITS => 3, SHIFT_BITS => 2)
		port map(in_clk => fast_clk, in_rst => rst, out_clk => slow_clk2);

	slow_clk3_gen : entity work.clkctr
		generic map(USE_RISING_EDGE => '1', COUNTER => 4, CLK_INIT => '0')
		port map(in_clk => fast_clk, in_reset => rst, out_clk => slow_clk3);


	--
	-- printing process
	--
	print_proc : process(fast_clk, rst)
	begin
		if VERBOSE = '1' then
			report	lf &
				"fast_clk = " & std_logic'image(fast_clk) &
				", slow_clk1 = " & std_logic'image(slow_clk1) &
				", slow_clk2 = " & std_logic'image(slow_clk2) &
				", slow_clk3 = " & std_logic'image(slow_clk3) &
				", reset: " & std_logic'image(rst);
		end if;
	end process;

end architecture;
