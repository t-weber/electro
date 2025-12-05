--
-- testing (unwanted) latch creation
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 27-nov-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 latch_tb.vhdl  &&  ghdl -e --std=08 latch_tb latch_tb_arch
-- ghdl -r --std=08 latch_tb latch_tb_arch --vcd=latch_tb.vcd --stop-time=1us
-- gtkwave latch_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;


entity latch_tb is end entity;


architecture latch_tb_arch of latch_tb is
	-- clock
	constant CLK_DELAY : time := 100 ns;
	signal clk : std_logic := '0';

	-- states
	type t_state is ( Start, One, Two, Finish );
	signal state, state_next : t_state := Start;

	signal val1, val1_next : std_logic_vector(7 downto 0) := (others => '0');
	signal val2 : std_logic_vector(7 downto 0) := (others => '0');

begin
	-- clock
	clk <= not clk after CLK_DELAY;


	-- flip-flops
	sim_ff : process(clk)
	begin
		if rising_edge(clk) then
			state <= state_next;
			val1 <= val1_next;
		end if;

		report "clk = "     & std_logic'image(clk)
		     & ", state = " & t_state'image(state)
		     & ", val1 = "  & to_hstring(val1)
		     & ", val2 = "  & to_hstring(val2);
	end process;


	-- combinatorics
	sim_comb : process(all)

	begin
		state_next <= state;
		val1_next <= val1;

		-- also explicit default action: creates a latch
		-- when assigned in a combinational block!
		val2 <= val2;

		case state is
			when Start =>
				state_next <= One;
				val1_next <= x"01";
				val2 <= x"01";

			when One =>
				state_next <= Two;
				val1_next <= x"12";
				val2 <= x"12";

			when Two =>
				state_next <= Finish;
				val1_next <= x"23";
				val2 <= x"23";

			when Finish =>
				null;
		end case;
	end process;

end architecture;
