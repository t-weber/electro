--
-- clock domain synchronisation testbench (passing from fast to slow clock)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date aug-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl ../mem/fifo.vhdl ../clock/clkgen.vhdl ../clock/clksync.vhdl clocks_tb2.vhdl  &&  ghdl -e --std=08 clocks_tb2 clocks_tb2_arch
-- ghdl -r --std=08 clocks_tb2 clocks_tb2_arch --vcd=clocks_tb2.vcd --stop-time=500ns
-- gtkwave clocks_tb2.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity clocks_tb2 is
end entity;


architecture clocks_tb2_arch of clocks_tb2 is
	constant VERBOSE : std_logic := '1';

	-- clocks
	constant FAST_CLK_HZ : natural := 40_000_000;
	constant SLOW_CLK_HZ : natural := 10_000_000;
	constant FAST_CLK_DELAY : time := 20 ns;
	signal fast_clk, slow_clk, rst : std_logic := '0';

	-- data generated in fast clock domain
	constant BITS : natural := 8;
	signal data : std_logic_vector(BITS - 1 downto 0) := (others => 'Z');
	signal stable_data : std_logic_vector(BITS - 1 downto 0);

begin
	--
	-- fast main clock
	--
	fast_clk <= not fast_clk after FAST_CLK_DELAY;


	--
	-- generate slow clock
	--
	slow_clk_gen : entity work.clkgen
		generic map(MAIN_HZ => FAST_CLK_HZ, CLK_HZ => SLOW_CLK_HZ, CLK_INIT => '0')
		port map(in_clk => fast_clk, in_reset => rst, out_clk => slow_clk);


	--
	-- data synchronisation
	--
	clk_sync : entity work.clksync(clksync_toslow)
		generic map(BITS => BITS, FIFO_ADDR_BITS => 8)
		port map(in_rst => rst,
			in_clk_fast => fast_clk, in_clk_slow => slow_clk,
			in_data => data, out_data => stable_data);


	--
	-- printing process
	--
	print_proc : process(fast_clk, rst)
	begin
		if VERBOSE = '1' then
			report	lf &
				"fast_clk = " & std_logic'image(fast_clk) &
				", slow_clk = " & std_logic'image(slow_clk) &
				", reset: " & std_logic'image(rst) &
				", data: " & to_hstring(stable_data);
		end if;
	end process;


	--
	-- fast clock process
	--
	sim_fast_clk : process(fast_clk)
		variable ctr : std_logic_vector(BITS - 1 downto 0) := (others => '0');
	begin
		if rising_edge(fast_clk) then
			-- generate some data (e.g., counter)
			data <= ctr;
			ctr := inc_logvec(ctr, 1);
		end if;
	end process;

end architecture;
