--
-- testing signal delays
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 27-nov-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 delay_tb.vhdl  &&  ghdl -e --std=08 delay_tb delay_tb_arch
-- ghdl -r --std=08 delay_tb delay_tb_arch --vcd=delay_tb.vcd --stop-time=500ns
-- gtkwave delay_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;


entity delay_tb is
	port(
		out_direct : out std_logic;
		out_sig : out std_logic;
		out_vianext : out std_logic;
		out_viareg : out std_logic
	);
end entity;


architecture delay_tb_arch of delay_tb is
	-- clock
	constant CLK_DELAY : time := 20 ns;
	signal clk : std_logic := '0';

	-- states
	type t_state is ( Start, One, Zero, Finish );
	signal state, state_next : t_state := Start;

	constant ctr_max : natural := 5;

	-- registered signals via next-state logic
	signal vianext, vianext_next : std_logic := '0';
	signal ctr1, ctr1_next : natural range 0 to ctr_max := 0;

	-- registered signals
	signal sig : std_logic := '0';
	signal ctr2 : natural range 0 to ctr_max := 0;

	-- registered signals using separate process
	signal viareg : std_logic := '0';

begin
	-- clock
	clk <= not clk after CLK_DELAY;


	-- outputs
	out_vianext <= vianext;
	out_sig <= sig;
	out_viareg <= viareg;


	-- flip-flops
	sim_ff : process(clk)
	begin
		if rising_edge(clk) then
			state <= state_next;
			vianext <= vianext_next;
			ctr1 <= ctr1_next;

			if state = Zero then
				ctr2 <= ctr2 + 1;
			end if;
		end if;

		report lf
			& "clk = "            & std_logic'image(clk)
			& ", state = "        & t_state'image(state)
			& ", state_next = "   & t_state'image(state_next)
			& lf
			& "vianext = "        & std_logic'image(vianext)
			& ", vianext_next = " & std_logic'image(vianext_next)
			& ", sig = "          & std_logic'image(sig)
			& ", viareg = "       & std_logic'image(viareg)
			& lf
			& "ctr1 = "           & natural'image(ctr1)
			& ", ctr1_next = "    & natural'image(ctr1_next)
			& ", ctr2 = "         & natural'image(ctr2)
			& lf
			& "out_vianext = "    & std_logic'image(out_vianext)
			& ", out_sig = "      & std_logic'image(out_sig)
			& ", out_viareg = "   & std_logic'image(out_viareg)
			& ", out_direct = "   & std_logic'image(out_direct);
	end process;


	-- (mostly) combinatorics
	sim_comb : process(all)
		-- variable without delay
		variable var1 : std_logic := '0';
		variable ctr3 : natural range 0 to ctr_max := 0;

	begin
		state_next <= state;
		vianext_next <= vianext;
		ctr1_next <= ctr1;

		sig <= '0';
		var1 := '0';
		--ctr2 <= 0;
		--ctr3 := 0;

		case state is
			when Start =>
				vianext_next <= '0';
				sig <= '0';
				var1 := '0';
				out_direct <= '0';

				state_next <= One;

			when One =>
				vianext_next <= '1';
				sig <= '1';
				var1 := '1';
				out_direct <= '1';

				state_next <= Zero;

			when Zero =>
				vianext_next <= '0';
				sig <= '0';
				var1 := '0';
				out_direct <= '0';

				ctr1_next <= ctr1 + 1;
				--ctr2 <= ctr2 + 1;
				ctr3 := ctr3 + 1;

				if ctr3 = ctr_max then
					state_next <= Finish;
				else
					state_next <= One;
				end if;

			when Finish =>
				null;
		end case;

		report "var1 = " & std_logic'image(var1)
			& ", ctr3 = " & natural'image(ctr3)
			& lf;
	end process;


	-- registered outputs in separate process
	sim_reg : process(clk)
	begin
		if rising_edge(clk) then
			viareg <= '0';
			case state_next is
				when Start =>
					viareg <= '0';
				when One =>
					viareg <= '1';
				when Zero =>
					viareg <= '0';
				when Finish =>
					null;
			end case;
		end if;
	end process;

end architecture;
