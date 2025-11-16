--
-- clock domain synchronisation testbench (passing from slow to fast clock)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 17-mar-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv/conv.vhdl ../lib/mem/fifo.vhdl ../lib/clock/clkgen.vhdl ../lib/clock/clksync.vhdl clocks_tb.vhdl  &&  ghdl -e --std=08 clocks_tb clocks_tb_arch
-- ghdl -r --std=08 clocks_tb clocks_tb_arch --vcd=clocks_tb.vcd --stop-time=500ns
-- gtkwave clocks_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity clocks_tb is
end entity;


architecture clocks_tb_arch of clocks_tb is
	constant VERBOSE : std_logic := '1';

	-- clocks
	constant MAIN_CLK_HZ : natural := 40_000_000;
	constant SLOW_CLK_HZ : natural := 10_000_000;
	constant MAIN_CLK_DELAY : time := 20 ns;
	signal main_clk, slow_clk, rst : std_logic := '0';

	-- data generated in slow clock domain
	constant BITS : natural := 8;
	signal data : std_logic_vector(BITS-1 downto 0);
	signal stable_data : std_logic_vector(BITS-1 downto 0);

begin
	--
	-- fast main clock
	--
	main_clk <= not main_clk after MAIN_CLK_DELAY;


	--
	-- generate slow clock
	--
	slow_clk_gen : entity work.clkgen
		generic map(MAIN_HZ => MAIN_CLK_HZ, CLK_HZ => SLOW_CLK_HZ, CLK_INIT => '0')
		port map(in_clk => main_clk, in_reset => rst, out_clk => slow_clk);


	--
	-- data synchronisation
	--
	clk_sync : entity work.clksync(clksync_tofast)
		generic map(BITS => BITS, FLIPFLOPS => 2)
		port map(in_rst => rst,
			in_clk_fast => main_clk,
			in_clk_slow => '0',  -- not needed here
			in_data => data, out_data => stable_data);


	--
	-- main clock process
	--
	sim_main_clk : process(main_clk, rst)
	begin
		if VERBOSE = '1' then
			report	lf &
				"main_clk = " & std_logic'image(main_clk) &
				", slow_clk = " & std_logic'image(slow_clk) &
				", reset: " & std_logic'image(rst) &
				", data: " & to_hstring(stable_data);
				--", data_buf: " & to_hstring(data_stable(NUM_FLIPFLOPS-1));
		end if;
	end process;


	--
	-- slow clock process
	--
	sim_slow_clk : process(slow_clk)
		variable ctr : std_logic_vector(BITS-1 downto 0) := (others => '0');
	begin
		if rising_edge(slow_clk) then
			-- generate some data (e.g., counter)
			data <= ctr;
			ctr := inc_logvec(ctr, 1);
		end if;
	end process;

end architecture;
