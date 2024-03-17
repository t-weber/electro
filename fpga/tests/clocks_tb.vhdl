--
-- clock domain synchronisation testbench (passing from slow to fast clock)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 17-mar-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  &&  ghdl -a --std=08 ../lib/clkgen.vhdl &&  ghdl -a --std=08 clocks_tb.vhdl  &&  ghdl -e --std=08 clocks_tb clocks_tb_arch
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

	-- flip-flops to pass the data to the fast clock domain
	constant NUM_FLIPFLOPS : natural := 2;
	signal data_stable : t_logicvecarray(0 to NUM_FLIPFLOPS-1)(BITS-1 downto 0);

begin
	-- main clock
	main_clk <= not main_clk after MAIN_CLK_DELAY;


	--
	-- generate slow clock
	--
	slow_clk_gen : entity work.clkgen
		generic map(MAIN_HZ => MAIN_CLK_HZ, CLK_HZ => SLOW_CLK_HZ, CLK_INIT => '0')
		port map(in_clk => main_clk, in_reset => rst, out_clk => slow_clk);


	--
	-- main clock process
	--
	sim_main_clk : process(main_clk, rst)
	begin
		if rst = '1' then
			data_stable <= (others => (others => '0'));

		elsif rising_edge(main_clk) then
			-- move data through flip-flop chain
			data_stable(0) <= data;

			for i in 1 to NUM_FLIPFLOPS - 1 loop
				data_stable(i) <= data_stable(i-1);
			end loop;
		end if;

		if VERBOSE = '1' then
			report	lf &
				"main_clk = " & std_logic'image(main_clk) &
				", slow_clk = " & std_logic'image(slow_clk) &
				", reset: " & std_logic'image(rst) &
				", data: " & to_hstring(data) &
				", data_buf: " & to_hstring(data_stable(NUM_FLIPFLOPS-1));
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
