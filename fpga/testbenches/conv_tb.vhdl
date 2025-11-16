--
-- tests the conversion routines
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 24 March 2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv/conv.vhdl  &&  ghdl -a --std=08 conv_tb.vhdl  &&  ghdl -e --std=08 conv_tb conv_tb_arch
-- ghdl -r --std=08 conv_tb conv_tb_arch --vcd=conv_tb.vcd --stop-time=1000ns
-- gtkwave conv_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity conv_tb is
end entity;


architecture conv_tb_arch of conv_tb is
	constant BITS : natural := 4;

	-- clock
	constant CLK_DELAY : time := 20 ns;
	signal clk : std_logic := '0';

	signal data, data_next : std_logic_vector(BITS-1 downto 0) := (others => '0');

begin
	-- generate clock
	clk <= not clk after CLK_DELAY;


	sim_ff : process(clk)
	begin
		if rising_edge(clk) then
			data <= data_next;
		end if;
	end process;


	sim_comb : process(data)
	begin
		data_next <= inc_logvec(data, 1);
	end process;


	sim_report : process(clk)
	begin
		report "clk = "      & std_logic'image(clk)
		     & ", data = 0x" & to_hstring(data)
		     & " = "         & integer'image(to_int(data));
	end process;

end architecture;
