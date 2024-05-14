--
-- test for ram module
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 20-feb-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../conv/conv.vhdl  &&   ghdl -a --std=08 ../mem/ram.vhdl  &&  ghdl -a --std=08 ram_tb.vhdl  &&  ghdl -e --std=08 ram_tb ram_tb_impl
-- ghdl -r --std=08 ram_tb ram_tb_impl --vcd=ram_tb.vcd --stop-time=25ns
-- gtkwave ram_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;



entity ram_tb is
	generic
	(
		-- main clock
		constant CLKDELAY : time := 2.5 ns;

		-- address and data widths
		constant ADDR_WIDTH : natural := 8;
		constant DATA_WIDTH : natural := 8
	);
end entity;



architecture ram_tb_impl of ram_tb is
	signal theclk, reset : std_logic := '1';

	-- states
	type t_state is ( Start, WriteTest, ReadTest, Finished );
	signal state, state_next : t_state := Start;

	signal enable, write_enable : std_logic := '0';

	signal addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal data, out_data : std_logic_vector(DATA_WIDTH-1 downto 0);
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
		end if;
	end process;


	--
	-- test input sequence
	--
	proc_test : process(all)
	begin
		-- defaults
		state_next <= state;

		reset <= '0';
		enable <= '1';
		write_enable <= '0';
		addr <= (others => '0');
		data <= (others => 'Z');

		case state is
			when Start =>
				reset <= '1';
				state_next <= WriteTest;

			when WriteTest =>
				write_enable <= '1';
				addr <= x"12";
				data <= x"78";
				state_next <= ReadTest;

			when ReadTest =>
				addr <= x"12";
				state_next <= Finished;

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
		report  lf &
			"clk = " & std_logic'image(theclk) &
			", state = " & t_state'image(state) &
			", addr = " & to_hstring(addr) &
			", data = " & to_hstring(data) &
			", out_data = " & to_hstring(out_data);
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- ram module
	---------------------------------------------------------------------------
	mod_ram : entity work.ram
		generic map(
			ADDR_BITS => ADDR_WIDTH, WORD_BITS => DATA_WIDTH,
			NUM_PORTS => 1
		)
		port map(
			in_clk => theclk, in_rst => reset,
			in_read_ena(0) => enable, in_write_ena(0) => write_enable,
			in_addr(0) => addr, in_data(0) => data,
			out_data(0) => out_data
		);
	---------------------------------------------------------------------------
end architecture;
