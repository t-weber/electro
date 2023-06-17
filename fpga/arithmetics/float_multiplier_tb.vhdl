--
-- multiplier testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 17-June-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 conv.vhdl  && ghdl -a --std=08 float_multiplier.vhdl  &&  ghdl -a --std=08 float_multiplier_tb.vhdl  &&  ghdl -e --std=08 float_multiplier_tb float_multiplier_tb_arch
-- ghdl -r --std=08 float_multiplier_tb float_multiplier_tb_arch --vcd=float_multiplier_tb.vcd --stop-time=1000ns
-- gtkwave float_multiplier_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity float_multiplier_tb is
end entity;


architecture float_multiplier_tb_arch of float_multiplier_tb is
	constant BITS : natural := 32;
	constant EXP_BITS : natural := 8;

	constant clk_delay : time := 10 ns;
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';

	signal ready, prev_ready, finished : std_logic := '0';
	signal a, b : std_logic_vector(BITS-1 downto 0) := (others => '0');
	signal prod : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
	-- clock
	clk <= not clk after clk_delay when finished = '0';

	-- instantiate modules
	mult_ent : entity work.float_multiplier
		generic map(BITS => BITS, EXP_BITS => EXP_BITS)
		port map(in_clk => clk, in_rst => rst,
			in_start => '1', out_ready => ready,
			in_a => a, in_b => b, out_prod => prod);

	sim : process(clk) begin
		rst <= '0';
		prev_ready <= ready;
		if prev_ready = '0' and ready = '1' then
			finished <= '1';
		end if;

		--a <= x"bf000000";  -- -0.5
		--b <= x"3e800000";  -- +0.25
		-- expected result: -0.125 = 0xbe000000

		--a <= int_to_logvec(16#bf9d70a3#, BITS);
		--b <= int_to_logvec(16#4015c28f#, BITS);
		a <= x"bf9d70a3";  -- -1.23
		b <= x"4015c28f";  -- +2.34
		-- expected result: -2.8782 = 0xc038346d

		report
			"clk = " & std_logic'image(clk) &
			", rst = " & std_logic'image(rst) &
			", ready = " & std_logic'image(ready) &
			", " & to_hstring(a) &
			" * " & to_hstring(b) &
			" = " & to_hstring(prod);
	end process;


end architecture;
