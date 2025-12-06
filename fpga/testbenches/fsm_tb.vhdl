--
-- testing fsm implementation variants
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 fsm_tb.vhdl  &&  ghdl -e --std=08 fsm_tb fsm_tb_arch
-- ghdl -r --std=08 fsm_tb fsm_tb_arch --vcd=fsm_tb.vcd --stop-time=25us
-- gtkwave fsm_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;


entity fsm_tb is
end entity;


architecture fsm_tb_arch of fsm_tb is
	-- clock
	constant CLK_DELAY : time := 1.0 us;
	constant MAIN_CLK : natural := 1_000_000;
	signal clk : std_logic := '0';

	-- reset
	constant RESET_DELAY : time := 1.5 us;
	signal rst : std_logic := '1';

	-- states
	type t_state is ( Start, One, Two, Three, Finish );
	signal fsm2_state, fsm2_state_next : t_state := Start;

	-- wait timer
	constant WAIT_DELAY : natural := MAIN_CLK * 5 / 1_000_000;  -- 5 us
	signal fsm2_wait_ctr, fsm2_wait_ctr_max : natural range 0 to WAIT_DELAY := 0;

begin
	-- clock
	clk <= not clk after CLK_DELAY / 2;


	---------------------------------------------------------------------------
	-- two-process fsm implementation
	---------------------------------------------------------------------------
	--
	-- flip-flops
	--
	fsm2_ff : process(clk, rst) is
	begin
		if rst then
			-- reset
			fsm2_state <= Start;
			fsm2_wait_ctr <= 0;

		elsif rising_edge(clk) then
			-- clock
			fsm2_state <= fsm2_state_next;

			if fsm2_wait_ctr = fsm2_wait_ctr_max or fsm2_state /= Start then
				fsm2_wait_ctr <= 0;
			else
				fsm2_wait_ctr <= fsm2_wait_ctr + 1;
			end if;
		end if;
	end process;


	--
	-- combinational logic
	--
	fsm2_comb : process(all) is
	begin
		fsm2_state_next <= fsm2_state;
		fsm2_wait_ctr_max <= 0;

		case fsm2_state is
			when Start =>
				fsm2_wait_ctr_max <= WAIT_DELAY;
				if fsm2_wait_ctr = fsm2_wait_ctr_max then
					fsm2_state_next <= One;
				end if;

			when One =>
				fsm2_state_next <= Two;

			when Two =>
				fsm2_state_next <= Three;

			when Three =>
				fsm2_state_next <= Finish;

			when Finish =>
				null;
		end case;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- one-process fsm implementation
	---------------------------------------------------------------------------
	--
	-- flip-flops and combinational logic
	--
	fsm1_proc : process(clk, rst) is
		variable fsm1_state : t_state := Start;
		variable fsm1_wait_ctr : natural range 0 to WAIT_DELAY := 0;
	begin
		if(rst) then
			-- reset
			fsm1_state := Start;
			fsm1_wait_ctr := 0;

		elsif rising_edge(clk) then
			-- clock
			case fsm1_state is
				when Start =>
					if fsm1_wait_ctr = WAIT_DELAY then
						fsm1_wait_ctr := 0;
						fsm1_state := One;
					else
						fsm1_wait_ctr := fsm1_wait_ctr + 1;
					end if;

				when One =>
					fsm1_state := Two;

				when Two =>
					fsm1_state := Three;

				when Three =>
					fsm1_state := Finish;

				when Finish =>
					null;
			end case;
		end if;

		--report fsm1_state'instance_name;
		report "t = "             & time'image(now)
			 & ", rst = "         & std_logic'image(rst)
			 & ", clk = "         & std_logic'image(clk)
			 & ", FSM1: state = " & t_state'image(fsm1_state)
			 & ", wait_ctr = "    & natural'image(fsm1_wait_ctr);
	end process;
	---------------------------------------------------------------------------


	--
	-- init process
	--
	init_proc : process is
	begin
		rst <= '1';
		wait for RESET_DELAY;
		rst <= '0';

		wait;
	end process;


	--
	-- debug output
	--
	report_proc : process(clk, rst) is
		--alias fsm1_state is <<variable .fsm_tb.fsm1_proc.fsm1_state : t_state>>;
	begin
		report "t = "             & time'image(now)
			 & ", rst = "         & std_logic'image(rst)
			 & ", clk = "         & std_logic'image(clk)
			 & ", FSM2: state = " & t_state'image(fsm2_state)
			 & ", wait_ctr = "    & natural'image(fsm2_wait_ctr);
	end process;

end architecture;
