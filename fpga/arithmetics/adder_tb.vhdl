--
-- adder testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 30-apr-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 conv.vhdl  &&  ghdl -a --std=08 adder.vhdl  &&  ghdl -a --std=08 adder_tb.vhdl  &&  ghdl -e --std=08 adder_tb adder_tb_arch
-- ghdl -r --std=08 adder_tb adder_tb_arch --vcd=adder_tb.vcd --stop-time=50ns
-- gtkwave adder_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity adder_tb is
end entity;


architecture adder_tb_arch of adder_tb is
	constant BITS : natural := 16;

	constant clk_delay : time := 10 ns;
	signal clk : std_logic := '0';

	signal a, b : std_logic_vector(BITS-1 downto 0) := (others => '0');
	signal sum : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
	-- clock
	clk <= not clk after clk_delay;

	-- instantiate modules
	adder_ent : entity work.ripplecarryadder
		generic map(BITS => BITS)
		port map(in_a => a, in_b => b, out_sum => sum);

	-- log process
	logger : process(clk) begin
		a <= int_to_logvec(123, BITS);
		b <= int_to_logvec(234, BITS);

		report "clk = " & std_logic'image(clk) &
			", " & integer'image(to_int(a)) &
			" + " & integer'image(to_int(b)) &
			" = " & integer'image(to_int(sum));
	end process;


end architecture;
