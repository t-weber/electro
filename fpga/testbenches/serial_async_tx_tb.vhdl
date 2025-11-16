--
-- serial controller testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 15-jun-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv/conv.vhdl  &&  ghdl -a --std=08 ../lib/clock/clkgen.vhdl  &&  ghdl -a --std=08 ../lib/comm/serial_async_tx.vhdl  &&  ghdl -a --std=08 serial_async_tx_tb.vhdl  &&  ghdl -e --std=08 serial_async_tx_tb serial_async_tx_tb_arch
-- ghdl -r --std=08 serial_async_tx_tb serial_async_tx_tb_arch --vcd=serial_async_tx_tb.vcd --stop-time=5000ns
-- gtkwave serial_async_tx_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity serial_async_tx_tb is
end entity;


architecture serial_async_tx_tb_arch of serial_async_tx_tb is
	constant VERBOSE : std_logic := '1';

	constant MAIN_HZ : natural := 40_000_000;
	constant SERIAL_HZ : natural := 9_000_000;
	constant BITS : natural := 8;

	constant CLK_DELAY : time := 20 ns;
	signal clk, rst : std_logic := '0';

	-- states
	type t_state is ( Reset, WriteData, NextData, Idle );
	signal state, next_state : t_state := Reset;

	signal start, ready : std_logic := '0';

	signal data : std_logic_vector(BITS-1 downto 0);
	signal serial_data : std_logic := '0';

	signal byte_finished, last_byte_finished : std_logic := '0';
	signal bus_cycle, bus_cycle_next : std_logic := '0';

	type t_data_arr is array(0 to 4 - 1) of std_logic_vector(BITS-1 downto 0);
	constant data_arr : t_data_arr := ( x"ff", x"11", x"01", x"10" );

	signal byte_ctr, next_byte_ctr : natural range 0 to data_arr'length := 0;

begin
	--
	-- clock
	--
	clk <= not clk after CLK_DELAY;
	bus_cycle <= byte_finished and (not last_byte_finished);
	bus_cycle_next <= (not byte_finished) and last_byte_finished;


	--
	-- instantiate modules
	--
	serial_tx_ent : entity work.serial_async_tx
		generic map(BITS => BITS, MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ)
		port map(in_clk => clk, in_reset => rst,
			in_enable => start, out_ready => ready,
			out_next_word => byte_finished,
			out_serial => serial_data, in_parallel => data);


	--
	-- flip-flops
	--
	ff : process(clk)
	begin
		if rising_edge(clk) then
			state <= next_state;
			byte_ctr <= next_byte_ctr;
			last_byte_finished <= byte_finished;
		end if;
	end process;


	-- combinatorics
	comb : process(state, bus_cycle, byte_ctr, ready)
	begin
		next_state <= state;
		next_byte_ctr <= byte_ctr;

		start <= '0';
		rst <= '0';
		data <= (others => '0');

		case state is
			when Reset =>
				rst <= '1';
				next_state <= WriteData;

			when WriteData =>
				start <= '1';
				data <= data_arr(byte_ctr);

				if bus_cycle = '1' then
					next_state <= NextData;
				end if;

			when NextData =>
				--if ready = '1' then
					if byte_ctr + 1 = data_arr'length then
						next_state <= Idle;
					else
						next_byte_ctr <= byte_ctr + 1;
						next_state <= WriteData;
					end if;
				--end if;

			when Idle =>
				null;

		end case;
	end process;


	--
	-- logging
	--
	log_proc : process(clk)
	begin
		if VERBOSE = '1' then
			report	lf &
				"clk = " & std_logic'image(clk) &
				", state: " & t_state'image(state) &
				", rst: " & std_logic'image(rst) &
				", start: " & std_logic'image(start) &
				", rdy: " & std_logic'image(ready) &
				", tx: " & to_hstring(data) &
				", nxt: " & std_logic'image(byte_finished) &
				--", cycle: " & std_logic'image(bus_cycle) &
				", sda: " & std_logic'image(serial_data) &
				", byte: " & integer'image(byte_ctr);
		end if;
	end process;

end architecture;
