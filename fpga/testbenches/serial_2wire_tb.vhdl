--
-- serial controller testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date apr-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  &&  ghdl -a --std=08 ../clock/clkgen.vhdl  &&  ghdl -a --std=08 ../comm/serial_2wire.vhdl  &&  ghdl -a --std=08 serial_2wire_tb.vhdl  &&  ghdl -e --std=08 serial_2wire_tb serial_2wire_tb_arch
-- ghdl -r --std=08 serial_2wire_tb serial_2wire_tb_arch --vcd=serial_2wire_tb.vcd --stop-time=5000ns
-- gtkwave serial_2wire_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity serial_2wire_tb is
end entity;


architecture serial_2wire_tb_arch of serial_2wire_tb is
	constant VERBOSE : std_logic := '1';

	constant MAIN_HZ : natural := 40_000_000;
	constant SERIAL_HZ : natural := 20_000_000;
	constant BITS : natural := 8;

	constant CLK_DELAY : time := 20 ns;
	signal clk, rst : std_logic := '0';

	signal start : std_logic := '0';
	signal ready : std_logic := '0';
	signal error : std_logic := '0';
	signal initial : std_logic := '1';

	signal data : std_logic_vector(BITS-1 downto 0);
	signal serial_data : std_logic := '0';
	signal serial_clk : std_logic := '0';
	signal byte_finished, last_byte_finished : std_logic := '0';
	signal bus_cycle : std_logic := '0';

	signal received_data : std_logic_vector(BITS-1 downto 0);

	signal byte_ctr : natural range 0 to 2 := 0;

begin
	-- clock
	clk <= not clk after CLK_DELAY;
	bus_cycle <= byte_finished and (not last_byte_finished);


	-- instantiate modules
	serial_ent : entity work.serial_2wire
		generic map(BITS => BITS, IGNORE_ERROR => '1',
			MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ)
		port map(in_clk => clk, in_reset => rst,
			in_enable => start, in_write => '1',
			in_addr_write => "10101010", in_addr_read => "10101011",
			out_err => error,
			out_ready => ready, out_word_finished => byte_finished,
			inout_clk => serial_clk, inout_serial => serial_data,
			in_parallel => data, out_parallel => received_data);


	sim : process(clk)
	begin
		last_byte_finished <= byte_finished;

		-- next byte to transmit
		if bus_cycle = '1' then
			byte_ctr <= byte_ctr + 1;
		end if;

		if rising_edge(clk) then
			if initial = '1' then
				start <= '0';
				rst <= '1';
				byte_ctr <= 0;
			else
				start <= '1';
				rst <= '0';
			end if;

			initial <= '0';

			if byte_ctr = 0 then
				data <= int_to_logvec(255, BITS);
			elsif byte_ctr = 1 then
				data <= int_to_logvec(2, BITS);
			elsif byte_ctr = 2 then
				data <= int_to_logvec(0, BITS);
				start <= '0';
			end if;
		end if;
	end process;


	mainclk_proc : process(clk)
	begin
		if VERBOSE = '1' then
			report	lf &
				"clk = " & std_logic'image(clk) &
				", reset: " & std_logic'image(rst) &
				", start: " & std_logic'image(start) &
				", tx: " & integer'image(to_int(data)) &
				", rx: " & integer'image(to_int(received_data)) &
				", next: " & std_logic'image(byte_finished) &
				", cycle: " & std_logic'image(bus_cycle) &
				", scl: " & std_logic'image(serial_clk) &
				", sda: " & std_logic'image(serial_data) &
				", err: " & std_logic'image(error) &
				", byte_ctr: " & integer'image(byte_ctr);
		end if;
	end process;


	serial_proc : process(serial_clk)
	begin
		--if falling_edge(serial_clk) then
		--	report  "scl = " & std_logic'image(serial_clk) &
		--		", sda: " & std_logic'image(serial_data) &
		--		", rx: " & to_hstring(received_data) &
		--		", next: " & std_logic'image(byte_finished);
		--end if;
	end process;

end architecture;
