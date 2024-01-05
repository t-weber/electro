--
-- floating point operations testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 17-June-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  && ghdl -a --std=08 ../arithmetics/float_ops.vhdl  &&  ghdl -a --std=08 float_ops_tb.vhdl  &&  ghdl -e --std=08 float_ops_tb float_ops_tb_arch
-- ghdl -r --std=08 float_ops_tb float_ops_tb_arch --vcd=float_ops_tb.vcd --stop-time=1000ns
-- gtkwave float_ops_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity float_ops_tb is
end entity;


architecture float_ops_tb_arch of float_ops_tb is
	constant BITS : natural := 32;
	constant EXP_BITS : natural := 8;
	--constant BITS : natural := 16;
	--constant EXP_BITS : natural := 5;
	constant MANT_BITS : natural := BITS - EXP_BITS - 1;

	constant clk_delay : time := 10 ns;
	signal clk : std_logic := '0';
	signal rst : std_logic := '1';

	signal op : std_logic_vector(1 downto 0) := "00";
	signal ready, prev_ready  : std_logic := '0';
	signal mult_finished, div_finished, add_finished, sub_finished : std_logic := '0';
	signal a, b : std_logic_vector(BITS-1 downto 0) := (others => '0');
	signal result : std_logic_vector(BITS-1 downto 0) := (others => '0');
begin
	-- clock
	clk <= not clk after clk_delay
		when mult_finished = '0' or div_finished = '0'
		or add_finished = '0' or sub_finished = '0';

	-- instantiate modules
	float_ent : entity work.float_ops
		generic map(BITS => BITS, EXP_BITS => EXP_BITS, MANT_BITS => MANT_BITS)
		port map(in_clk => clk, in_rst => rst,
			in_enable => '1', in_op => op,
			in_start => '1', out_ready => ready,
			in_a => a, in_b => b, out_result => result);

	float_sim : process(clk) begin
		rst <= '0';

		if prev_ready = '1' and ready = '1' then
			report "";
		end if;

		if op = "00" then
			prev_ready <= ready;
			if prev_ready = '0' and ready = '1' then
				op <= "01";
				mult_finished <= '1';
			end if;

			a <= x"bf000000";  -- -0.5
			b <= x"3e800000";  -- +0.25
			-- expected result: -0.125 = 0xbe000000

			--a <= int_to_logvec(16#bf9d70a3#, BITS);
			--b <= int_to_logvec(16#4015c28f#, BITS);
			--a <= x"bf9d70a3";  -- -1.23
			--b <= x"4015c28f";  -- +2.34
			-- expected result: -2.8782 = 0xc038346d

			--a <= x"cc00";  -- -16
			--b <= x"5640";  -- +100
			-- expected result: -1600 = 0xe640

			report
				"clk = " & std_logic'image(clk) &
				", rst = " & std_logic'image(rst) &
				", ready = " & std_logic'image(ready) &
				", " & to_hstring(a) &
				" * " & to_hstring(b) &
				" = " & to_hstring(result);

		elsif op = "01" then
			prev_ready <= ready;
			if prev_ready = '0' and ready = '1' then
				op <= "10";
				div_finished <= '1';
			end if;

			a <= x"bf9d70a3";  -- -1.23
			b <= x"4015c28f";  -- +2.34
			-- expected result: -0.52564 = 0xbf069069

			--a <= x"cc00";  -- -16
			--b <= x"5640";  -- +100
			-- expected result: -0.16 = 0xb11e

			report
				"clk = " & std_logic'image(clk) &
				", rst = " & std_logic'image(rst) &
				", ready = " & std_logic'image(ready) &
				", " & to_hstring(a) &
				" / " & to_hstring(b) &
				" = " & to_hstring(result);

		elsif op = "10" then
			prev_ready <= ready;
			if prev_ready = '0' and ready = '1' then
				op <= "11";
				add_finished <= '1';
			end if;

			a <= x"bf9d70a3";  -- -1.23
			b <= x"4015c28f";  -- +2.34
			-- expected result: 1.11 = 0x3f8e147a

			--a <= x"cc00";  -- -16
			--b <= x"5640";  -- +100
			-- expected result: 84 = 0x5540

			report
				"clk = " & std_logic'image(clk) &
				", rst = " & std_logic'image(rst) &
				", ready = " & std_logic'image(ready) &
				", " & to_hstring(a) &
				" + " & to_hstring(b) &
				" = " & to_hstring(result);

		elsif op = "11" then
			prev_ready <= ready;
			if prev_ready = '0' and ready = '1' then
				sub_finished <= '1';
			end if;

			a <= x"bf9d70a3";  -- -1.23
			b <= x"4015c28f";  -- +2.34
			-- expected result: -3.57 = 0xc0647ae1

			--a <= x"cc00";  -- -16
			--b <= x"5640";  -- +100
			-- expected result: -116 = 0xd740

			report
				"clk = " & std_logic'image(clk) &
				", rst = " & std_logic'image(rst) &
				", ready = " & std_logic'image(ready) &
				", " & to_hstring(a) &
				" - " & to_hstring(b) &
				" = " & to_hstring(result);
		end if;
end process;

end architecture;
