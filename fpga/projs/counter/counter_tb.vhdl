--
-- counter testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 15-apr-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv/conv.vhdl  &&  ghdl -a --std=08 counter.vhdl  &&  ghdl -a --std=08 ../display/sevenseg.vhdl  &&  ghdl -a --std=08 counter_tb.vhdl  &&  ghdl -e --std=08 counter_tb counter_tb_arch
-- ghdl -r --std=08 counter_tb counter_tb_arch --vcd=counter_tb.vcd --stop-time=250ns
-- gtkwave counter_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity counter_tb is
end entity;


architecture counter_tb_arch of counter_tb is

	constant clk_delay : time := 10 ns;
	signal clk : std_logic := '0';

	signal count : std_logic_vector(3 downto 0) := (others => '0');
	signal hex_out : std_logic_vector(6 downto 0);

begin

	-- clock
	clk <= not clk after clk_delay;


	-- instantiate modules
	counter_ent : entity work.counter
		generic map(num_ctrbits => 4)
		port map(in_rst => '0', in_clk => clk, out_ctr => count);

	sevenseg_ent : entity work.sevenseg
		generic map(zero_is_on => '0', inverse_numbering => '0')
		port map(in_digit => count, out_leds => hex_out);


	-- log process
	logger : process(clk) begin
		report "clk = " & std_logic'image(clk) &
			", count = " & integer'image(to_int(count)) &
			", hex = " & to_hstring(hex_out);
	end process;


end architecture;
