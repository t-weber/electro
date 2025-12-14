--
-- divider testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 7-January-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv/conv.vhdl  &&  ghdl -a --std=08 ../lib/arithmetics/adder.vhdl  &&  ghdl -a --std=08 ../lib/arithmetics/divider.vhdl  &&  ghdl -a --std=08 divider_tb.vhdl  &&  ghdl -e --std=08 divider_tb divider_tb_arch
-- ghdl -r --std=08 divider_tb divider_tb_arch --vcd=divider_tb.vcd --stop-time=1000ns
-- gtkwave divider_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity divider_tb is
end entity;


architecture divider_tb_arch of divider_tb is
	constant BITS : natural := 16;

	constant clk_delay : time := 10 ns;
	signal clk, rst : std_logic := '0';

	signal start, finished : std_logic := '0';
	signal initial : std_logic := '1';

	signal a, b : std_logic_vector(BITS-1 downto 0) := (others => '0');
	signal quotient, remainder : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
	-- clock
	clk <= not clk after clk_delay when finished = '0';

	-- instantiate modules
	div_ent : entity work.divider
		generic map(BITS => BITS)
		port map(in_clk => clk, in_rst => rst,
			in_start => start, out_finished => finished,
			in_a => a, in_b => b, out_quot => quotient, out_rem => remainder);

	sim : process(clk) begin
		if initial = '1' then
			start <= '0';
			rst <= '1';
		else
			start <= '1';
			rst <= '0';
		end if;

		a <= int_to_logvec(500, BITS);
		b <= int_to_logvec(123, BITS);
		initial <= '0';

		report "clk = " & std_logic'image(clk) &
			", finished = " & std_logic'image(finished) &
			", " & integer'image(to_int(a)) &
			" / " & integer'image(to_int(b)) &
			" = " & integer'image(to_int(quotient)) &
			" (rem: " & integer'image(to_int(remainder)) & ")";
	end process;


end architecture;
