--
-- testing signal delays
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 27-nov-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 delay_tb.vhdl  &&  ghdl -e --std=08 delay_tb delay_tb_arch
-- ghdl -r --std=08 delay_tb delay_tb_arch --vcd=delay_tb.vcd --stop-time=700ns
-- gtkwave delay_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;


entity delay_tb is
end entity;


architecture delay_tb_arch of delay_tb is
	-- clock
	constant CLK_DELAY : time := 20 ns;
	signal clk : std_logic := '0';

	-- states
	type t_state is ( A, B, C, D );
	signal state, state_next : t_state := A;

	constant ctr_max : natural := 15;

	-- registered signals via next-state logic
	signal sig1, sig1_next : std_logic := '0';
	signal ctr1, ctr1_next : natural range 0 to ctr_max := 0;

	-- registered signals
	signal sig2 : std_logic := '0';
	signal ctr2 : natural range 0 to ctr_max := 0;

begin
	-- clock
	clk <= not clk after CLK_DELAY;


	-- flip-flops
	sim_ff : process(clk)
	begin
		if rising_edge(clk) then
			state <= state_next;
			sig1 <= sig1_next;
			ctr1 <= ctr1_next;

			if state = C then
				ctr2 <= ctr2 + 1;
			end if;
		end if;

		report lf
			& "clk = "          & std_logic'image(clk)
			& ", state = "      & t_state'image(state)
			& ", state_next = " & t_state'image(state_next)
			& lf
			& "sig1 = "         & std_logic'image(sig1)
			& ", sig1_next = "  & std_logic'image(sig1_next)
			& ", sig2 = "       & std_logic'image(sig2)
			& lf
			& "ctr1 = "         & natural'image(ctr1)
			& ", ctr1_next = "  & natural'image(ctr1_next)
			& ", ctr2 = "       & natural'image(ctr2);
	end process;


	-- combinatorics
	sim_comb : process(all)
		-- variable without delay
		variable var1 : std_logic := '0';
		variable ctr3 : natural range 0 to ctr_max := 0;

	begin
		state_next <= state;
		sig1_next <= sig1;
		ctr1_next <= ctr1;

		sig2 <= '0';
		var1 := '0';
		--ctr2 <= 0;
		--ctr3 := 0;

		case state is
			when A =>
				state_next <= B;
				sig1_next <= '0';
				sig2 <= '0';
				var1 := '0';

			when B =>
				state_next <= C;
				sig1_next <= '1';
				sig2 <= '1';
				var1 := '1';

			when C =>
				sig1_next <= '0';
				sig2 <= '0';
				var1 := '0';

				ctr1_next <= ctr1 + 1;
				--ctr2 <= ctr2 + 1;
				ctr3 := ctr3 + 1;

				if ctr3 = ctr_max then
					state_next <= D;
				end if;

			when D =>
				null;
		end case;

		report "var1 = " & std_logic'image(var1)
			& ", ctr3 = " & natural'image(ctr3)
			& lf;
	end process;

end architecture;
