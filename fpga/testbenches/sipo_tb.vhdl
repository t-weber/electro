--
-- test for sipo module
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 12-apr-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/mem/sipo.vhdl sipo_tb.vhdl  &&  ghdl -e --std=08 sipo_tb sipo_tb_impl
-- ghdl -r --std=08 sipo_tb sipo_tb_impl --vcd=sipo_tb.vcd --stop-time=100ns
-- gtkwave sipo_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;


entity sipo_tb is end entity;


architecture sipo_tb_impl of sipo_tb is
	-- main clock
	constant CLKDELAY : time := 2.5 ns;

	-- data width
	constant BITS : natural := 8;

	-- clock & rst
	signal clk, rst : std_logic := '1';

	-- states
	type t_state is (Start,
		Bit1, Bit2, Bit3, Bit4,
		Bit5, Bit6, Bit7, Bit8,
		Finished, Finished2);
	signal state, state_next : t_state := Start;

	signal serial_data : std_logic := '0';
	signal parallel_data : std_logic_vector(BITS - 1 downto 0)
		:= (others => '0');
begin

	---------------------------------------------------------------------------
	-- clock
	---------------------------------------------------------------------------
	clk <= not clk after CLKDELAY when state /= Finished2;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- state machine
	---------------------------------------------------------------------------
	proc_ff : process(clk) is
	begin
		-- clock
		if rising_edge(clk) then
			state <= state_next;
		end if;
	end process;


	--
	-- test input sequence
	--
	proc_test : process(all)
	begin
		-- defaults
		state_next <= state;
		rst <= '0';
		serial_data <= '0';

		case state is
			when Start =>
				report "==== START ====";
				rst <= '1';
				state_next <= Bit1;

			when Bit1 =>
				serial_data <= '1';
				state_next <= Bit2;

			when Bit2 =>
				serial_data <= '0';
				state_next <= Bit3;

			when Bit3 =>
				serial_data <= '0';
				state_next <= Bit4;

			when Bit4 =>
				serial_data <= '1';
				state_next <= Bit5;

			when Bit5 =>
				serial_data <= '0';
				state_next <= Bit6;

			when Bit6 =>
				serial_data <= '0';
				state_next <= Bit7;

			when Bit7 =>
				serial_data <= '1';
				state_next <= Bit8;

			when Bit8 =>
				serial_data <= '0';
				state_next <= Finished;

			when Finished =>
				state_next <= Finished2;

			when Finished2 =>
				report "==== FINISHED ====";
		end case;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- debug output
	---------------------------------------------------------------------------
	report_proc : process(clk)
	begin
		if rising_edge(clk) then
			report  lf &
				"clk = " & std_logic'image(clk) &
				", rst = " & std_logic'image(rst) &
				", state = " & t_state'image(state) &
				", serial_data = " & std_logic'image(serial_data) &
				", parallel_data = 0x" & to_hstring(parallel_data) &
				" = 0b" & to_string(parallel_data);
		end if;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- sipo module
	---------------------------------------------------------------------------
	mod_sipo : entity work.sipo
		generic map(BITS => BITS, SHIFT_RIGHT => '1')
		port map(in_rst => rst, in_clk => clk,
			in_serial => serial_data, out_parallel => parallel_data);
	---------------------------------------------------------------------------
end architecture;
