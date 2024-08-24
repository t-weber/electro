--
-- test for stack module
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-aug-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl ../mem/stack.vhdl stack_tb.vhdl  &&  ghdl -e --std=08 stack_tb stack_tb_impl
-- ghdl -r --std=08 stack_tb stack_tb_impl --vcd=stack_tb.vcd --stop-time=25ns
-- gtkwave stack_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;



entity stack_tb is
	generic
	(
		-- main clock
		constant CLKDELAY : time := 2.5 ns;

		-- address and data widths
		constant ADDR_WIDTH : natural := 8;
		constant DATA_WIDTH : natural := 8
	);
end entity;



architecture stack_tb_impl of stack_tb is
	signal theclk, reset : std_logic := '1';

	-- states
	type t_state is (
		Start, WaitReady,
		PushTest1, PushTest2,
		PopTest,
		Finished
	);
	signal state, state_next : t_state := Start;
	signal state_after_ready, state_after_ready_next : t_state := Start;

	signal cmd : std_logic_vector(1 downto 0);
	signal data, data_next, top : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal ready : std_logic;
begin

	---------------------------------------------------------------------------
	-- clock
	---------------------------------------------------------------------------
	theclk <= not theclk after CLKDELAY;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- state machine
	---------------------------------------------------------------------------
	proc_ff : process(theclk) is
	begin
		-- clock
		if rising_edge(theclk) then
			state <= state_next;
			state_after_ready <= state_after_ready_next;
			data <= data_next;
		end if;
	end process;


	--
	-- test input sequence
	--
	proc_test : process(all)
	begin
		-- defaults
		state_next <= state;
		state_after_ready_next <= state_after_ready;
		data_next <= data;

		reset <= '0';
		cmd <= "00";

		case state is
			when Start =>
				reset <= '1';
				state_after_ready_next <= PushTest1;
				state_next <= WaitReady;

			when WaitReady =>
				if ready = '1' then
					state_next <= state_after_ready;
				end if;

			when PushTest1 =>
				cmd <= "01";
				data_next <= x"12";
				state_next <= WaitReady;
				state_after_ready_next <= PushTest2;

			when PushTest2 =>
				cmd <= "01";
				data_next <= x"98";
				state_next <= WaitReady;
				state_after_ready_next <= PopTest;

			when PopTest =>
				cmd <= "10";
				state_next <= WaitReady;
				state_after_ready_next <= Finished;

			when Finished =>
				report "==== FINISHED ====";
		end case;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- debug output
	---------------------------------------------------------------------------
	report_proc : process(theclk)
	begin
		if rising_edge(theclk) then
			report  --lf &
				"clk = " & std_logic'image(theclk) &
				", state = " & t_state'image(state) &
				", data = 0x" & to_hstring(data) & " = 0b" & to_string(data) &
				", stack_top = 0x" & to_hstring(top);
		end if;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- stack module
	---------------------------------------------------------------------------
	mod_stack : entity work.stack
		generic map(ADDR_BITS => ADDR_WIDTH, WORD_BITS => DATA_WIDTH)
		port map(
			in_clk => theclk, in_rst => reset,
			in_cmd => cmd, in_data => data,
			out_top => top, out_ready => ready
		);
	---------------------------------------------------------------------------
end architecture;
