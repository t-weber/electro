--
-- testing fsm implementation variants
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 fsm.vhdl  &&  ghdl -e --std=08 fsm fsm_arch
-- ghdl -r --std=08 fsm fsm_arch --vcd=fsm.vcd --stop-time=15us
-- gtkwave fsm.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;


entity fsm is
end entity;


architecture fsm_arch of fsm is
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
	signal fsm3_state, fsm3_state_next : t_state := Start;

	-- wait timer
	constant WAIT_DELAY : natural := MAIN_CLK * 5 / 1_000_000;  -- 5 us
	signal fsm2_wait_ctr, fsm2_wait_ctr_max : natural range 0 to WAIT_DELAY := 0;
	signal fsm3_wait_ctr, fsm3_wait_ctr_max : natural range 0 to WAIT_DELAY := 0;

	-- "outputs"
	signal fsm1_out, fsm2_out, fsm3_out : std_logic;

begin
	-- clock
	clk <= not clk after CLK_DELAY / 2;


	---------------------------------------------------------------------------
	-- three-process fsm implementation
	-- (here, outputs are associated with states)
	---------------------------------------------------------------------------
	--
	-- flip-flops
	--
	fsm3_ff : process(clk, rst) is
	begin
		if rst then
			-- reset
			fsm3_state <= Start;
			fsm3_wait_ctr <= 0;

		elsif rising_edge(clk) then
			-- clock
			fsm3_state <= fsm3_state_next;

			if fsm3_wait_ctr = fsm3_wait_ctr_max then
				fsm3_wait_ctr <= 0;
			else
				fsm3_wait_ctr <= fsm3_wait_ctr + 1;
			end if;
		end if;
	end process;


	--
	-- combinational logic
	--
	fsm3_comb : process(all) is
	begin
		fsm3_state_next <= fsm3_state;
		fsm3_wait_ctr_max <= 0;

		case fsm3_state is
			when Start =>
				fsm3_wait_ctr_max <= WAIT_DELAY;
				if fsm3_wait_ctr = fsm3_wait_ctr_max then
					fsm3_state_next <= One;
				end if;

			when One =>
				fsm3_state_next <= Two;

			when Two =>
				fsm3_state_next <= Three;

			when Three =>
				fsm3_state_next <= Finish;

			when Finish =>
				null;
		end case;
	end process;


	--
	-- combinational output logic
	--
	fsm3_output_comb : process(all) is
	begin
		fsm3_out <= '0';

		case fsm3_state is
			when One | Three =>
				fsm3_out <= '1';

			when others =>
				null;
		end case;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- two-process fsm implementation
	-- (here, outputs are associated with states)
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

			if fsm2_wait_ctr = fsm2_wait_ctr_max then
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
		fsm2_out <= '0';

		case fsm2_state is
			when Start =>
				fsm2_wait_ctr_max <= WAIT_DELAY;
				if fsm2_wait_ctr = fsm2_wait_ctr_max then
					fsm2_state_next <= One;
				end if;

			when One =>
				fsm2_state_next <= Two;
				fsm2_out <= '1';

			when Two =>
				fsm2_state_next <= Three;

			when Three =>
				fsm2_state_next <= Finish;
				fsm2_out <= '1';

			when Finish =>
				null;
		end case;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- one-process fsm implementation
	-- (here, outputs are automatically registered, change on transition
	-- (and not on state) and have to be set earlier to not be delayed)
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
			fsm1_out <= '0';

		elsif rising_edge(clk) then
			-- clock
			fsm1_out <= '0';

			case fsm1_state is
				when Start =>
					if fsm1_wait_ctr = WAIT_DELAY then
						fsm1_wait_ctr := 0;
						fsm1_state := One;
						fsm1_out <= '1';
					else
						fsm1_wait_ctr := fsm1_wait_ctr + 1;
					end if;

				when One =>
					fsm1_state := Two;

				when Two =>
					fsm1_state := Three;
					fsm1_out <= '1';

				when Three =>
					fsm1_state := Finish;

				when Finish =>
					null;
			end case;
		end if;

		--assert fsm1_state = fsm2_state
		--	report "Invalid state (1, 2)." severity error;
		--assert fsm1_wait_ctr = fsm2_wait_ctr
		--	report "Invalid counter (1, 2)." severity error;
		--assert fsm1_out = fsm2_out
		--	report "Invalid output (1, 2)." severity error;

		--report fsm1_state'instance_name;
		report "t = "             & time'image(now) & ", "
			 & "rst = "         & std_logic'image(rst) & ", "
			 & "clk = "         & std_logic'image(clk) & ", " & lf & ht
			 & "FSM1: state = " & t_state'image(fsm1_state) & ", "
			 & "wait_ctr = "    & natural'image(fsm1_wait_ctr) & ", "
			 & "output = "      & std_logic'image(fsm1_out) & lf;
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
		--alias fsm1_state is <<variable .fsm.fsm1_proc.fsm1_state : t_state>>;
	begin
		assert fsm3_state = fsm2_state
			report "Invalid state (2, 3)." severity error;
		assert fsm3_wait_ctr = fsm2_wait_ctr
			report "Invalid counter (2, 3)." severity error;
		assert fsm3_out = fsm2_out
			report "Invalid output (2, 3)." severity error;

		report "t = "             & time'image(now) & ", "
			 & "rst = "         & std_logic'image(rst) & ", "
			 & "clk = "         & std_logic'image(clk) & ", " & lf & ht
			 & "FSM2: state = " & t_state'image(fsm2_state) & ", "
			 & "wait_ctr = "    & natural'image(fsm2_wait_ctr) & ", "
			 & "output = "      & std_logic'image(fsm2_out) & ", " & lf & ht
			 & "FSM3: state = " & t_state'image(fsm3_state) & ", "
			 & "wait_ctr = "    & natural'image(fsm3_wait_ctr) & ", "
			 & "output = "      & std_logic'image(fsm3_out); --& lf;
	end process;

end architecture;
