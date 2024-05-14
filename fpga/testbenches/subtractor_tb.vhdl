--
-- subtractor testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 13-May-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl  &&  ghdl -a --std=08 ../arithmetics/subtractor.vhdl  &&  ghdl -a --std=08 subtractor_tb.vhdl  &&  ghdl -e --std=08 subtractor_tb subtractor_tb_arch
-- ghdl -r --std=08 subtractor_tb subtractor_tb_arch --vcd=subtractor_tb.vcd --stop-time=50ns
-- gtkwave subtractor_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity subtractor_tb is
end entity;


architecture subtractor_tb_arch of subtractor_tb is
	constant BITS : natural := 16;

	constant clk_delay : time := 10 ns;
	signal clk : std_logic := '0';

	signal a, b : std_logic_vector(BITS-1 downto 0) := (others => '0');
	signal diff : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
	-- clock
	clk <= not clk after clk_delay;

	-- instantiate modules
	subtractor_ent : entity work.rippleborrowsubtractor
		generic map(BITS => BITS)
		port map(in_a => a, in_b => b, out_diff => diff);

	-- log process
	logger : process(clk) begin
		a <= int_to_logvec(234, BITS);
		b <= int_to_logvec(123, BITS);

		if a >= b then
			report "clk = " & std_logic'image(clk) &
				", " & integer'image(to_int(a)) &
				" - " & integer'image(to_int(b)) &
				" = " & integer'image(to_int(diff));
		else
			report "clk = " & std_logic'image(clk) &
				", " & integer'image(to_int(a)) &
				" - " & integer'image(to_int(b)) &
				" = -" & integer'image(to_int(not diff)+1);
		end if;
	end process;


end architecture;
