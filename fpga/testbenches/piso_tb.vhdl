
--
-- test for piso module
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 12-apr-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/mem/piso.vhdl piso_tb.vhdl  &&  ghdl -e --std=08 piso_tb piso_tb_impl
-- ghdl -r --std=08 piso_tb piso_tb_impl --vcd=piso_tb.vcd --stop-time=100ns
-- gtkwave piso_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;


entity piso_tb is end entity;


architecture piso_tb_impl of piso_tb is
	-- main clock
	constant CLKDELAY : time := 2.5 ns;

	-- data width
	constant BITS : natural := 8;

	-- clock & rst
	signal clk, rst : std_logic := '1';

	-- states
	type t_state is (Start, Input, Output);
	signal state, state_next : t_state := Start;

	signal capture : std_logic := '0';
	signal serial_data : std_logic := '0';
	signal parallel_data : std_logic_vector(BITS - 1 downto 0)
		:= (0 => '1', 3 => '1', 5 => '1', others => '0');
begin

	---------------------------------------------------------------------------
	-- clock
	---------------------------------------------------------------------------
	clk <= not clk after CLKDELAY;
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
		capture <= '0';

		case state is
			when Start =>
				report "==== START ====";
				rst <= '1';
				state_next <= Input;

			when Input =>
				capture <= '1';
				state_next <= Output;

			when Output =>
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
				", capture = " & std_logic'image(capture) &
				", parallel_data = 0x" & to_hstring(parallel_data) &
				" = 0b" & to_string(parallel_data) &
				", serial_data = " & std_logic'image(serial_data);
		end if;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- piso module
	---------------------------------------------------------------------------
	mod_piso : entity work.piso
		generic map(BITS => BITS, SHIFT_RIGHT => '1')
		port map(in_rst => rst, in_clk => clk,
			out_serial => serial_data, in_rotate => '0',
			in_parallel => parallel_data, in_capture => capture);
	---------------------------------------------------------------------------
end architecture;
