--
-- multiplier testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 1-May-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl  &&  ghdl -a --std=08 ../arithmetics/adder.vhdl  &&ghdl -a --std=08 ../arithmetics/multiplier.vhdl  &&  ghdl -a --std=08 multiplier_tb.vhdl  &&  ghdl -e --std=08 multiplier_tb multiplier_tb_arch
-- ghdl -r --std=08 multiplier_tb multiplier_tb_arch --vcd=multiplier_tb.vcd --stop-time=1000ns
-- gtkwave multiplier_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity multiplier_tb is
end entity;


architecture multiplier_tb_arch of multiplier_tb is
	constant IN_BITS : natural := 8;
	constant OUT_BITS : natural := 16;

	constant clk_delay : time := 10 ns;
	signal clk, rst : std_logic := '0';

	signal start, finished : std_logic := '0';
	signal initial : std_logic := '1';

	signal a, b : std_logic_vector(IN_BITS-1 downto 0) := (others => '0');
	signal prod : std_logic_vector(OUT_BITS-1 downto 0) := (others => '0');
begin
	-- clock
	clk <= not clk after clk_delay when finished = '0';

	-- instantiate modules
	mult_ent : entity work.multiplier
		generic map(IN_BITS => IN_BITS, OUT_BITS => OUT_BITS)
		port map(in_clk => clk, in_rst => rst,
			in_start => start, out_finished => finished,
			in_a => a, in_b => b, out_prod => prod);

	sim : process(clk) begin
		if initial = '1' then
			start <= '0';
			rst <= '1';
		else
			start <= '1';
			rst <= '0';
		end if;

		a <= int_to_logvec(123, IN_BITS);
		b <= int_to_logvec(234, IN_BITS);
		initial <= '0';

		report "clk = " & std_logic'image(clk) &
			", finished = " & std_logic'image(finished) &
			", " & integer'image(to_int(a)) &
			" * " & integer'image(to_int(b)) &
			" = " & integer'image(to_int(prod));
	end process;


end architecture;
