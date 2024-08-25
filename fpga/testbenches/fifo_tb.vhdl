--
-- test for fifo module
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-aug-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl ../mem/fifo.vhdl fifo_tb.vhdl  &&  ghdl -e --std=08 fifo_tb fifo_tb_impl
-- ghdl -r --std=08 fifo_tb fifo_tb_impl --vcd=fifo_tb.vcd --stop-time=100ns
-- gtkwave fifo_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;


entity fifo_tb is end entity;


architecture fifo_tb_impl of fifo_tb is
	-- main clock
	constant CLKDELAY : time := 2.5 ns;

	-- address and data widths
	constant ADDR_WIDTH : natural := 8;
	constant DATA_WIDTH : natural := 8;


	signal theclk, reset : std_logic := '1';

	-- states
	type t_state is (
		Start,
		WaitReadyIns, WaitReadyRem,
		InsTest1, InsTest2,
		RemTest1, RemTest2, RemTest3,
		Finished
	);
	signal state, state_next : t_state := Start;
	signal state_after_ready, state_after_ready_next : t_state := Start;

	signal insert, remove : std_logic;
	signal empty : std_logic;
	signal data, data_next, back : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal ready_ins, ready_rem : std_logic;
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
		insert <= '0';
		remove <= '0';

		case state is
			when Start =>
				reset <= '1';
				state_after_ready_next <= InsTest1;
				state_next <= WaitReadyIns;

			when WaitReadyIns =>
				if ready_ins = '1' then
					state_next <= state_after_ready;
				end if;

			when WaitReadyRem =>
				if ready_rem = '1' then
					state_next <= state_after_ready;
				end if;

			when InsTest1 =>
				insert <= '1';
				data_next <= x"12";
				state_next <= WaitReadyIns;
				state_after_ready_next <= InsTest2;

			when InsTest2 =>
				insert <= '1';
				data_next <= x"98";
				state_next <= WaitReadyRem;
				state_after_ready_next <= RemTest1;

			when RemTest1 =>
				remove <= '1';
				state_next <= WaitReadyRem;
				state_after_ready_next <= RemTest2;

			when RemTest2 =>
				remove <= '1';
				state_next <= WaitReadyRem;
				state_after_ready_next <= RemTest3;

			when RemTest3 =>
				remove <= '1';
				state_next <= WaitReadyRem;
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
			report  lf &
				"clk = " & std_logic'image(theclk) &
				", state = " & t_state'image(state) &
				", data = 0x" & to_hstring(data) & " = 0b" & to_string(data) &
				", fifo_back = 0x" & to_hstring(back) &
				", empty = " & std_logic'image(empty);
		end if;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- stack module
	---------------------------------------------------------------------------
	mod_fifo : entity work.fifo
		generic map(ADDR_BITS => ADDR_WIDTH, WORD_BITS => DATA_WIDTH)
		port map(
			in_clk => theclk, in_rst => reset,
			in_data => data, out_back => back,
			in_insert => insert, in_remove => remove,
			out_ready_to_insert => ready_ins,
			out_ready_to_remove => ready_rem,
			out_empty => empty
		);
	---------------------------------------------------------------------------
end architecture;
