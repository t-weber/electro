--
-- serial controller testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-nov-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  &&  ghdl -a --std=08 ../clock/clkgen.vhdl  &&  ghdl -a --std=08 ../comm/serial.vhdl  &&  ghdl -a --std=08 serial_tb.vhdl  &&  ghdl -e --std=08 serial_tb serial_tb_arch
-- ghdl -r --std=08 serial_tb serial_tb_arch --vcd=serial_tb.vcd --stop-time=5000ns
-- gtkwave serial_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity serial_tb is
end entity;


architecture serial_tb_arch of serial_tb is
	constant VERBOSE : std_logic := '0';

	constant MAIN_HZ : natural := 40_000_000;
	constant SERIAL_HZ : natural := 9_000_000;
	constant BITS : natural := 8;

	constant CLK_DELAY : time := 20 ns;
	signal clk, rst : std_logic := '0';

	signal start : std_logic := '0';
	signal ready : std_logic := '0';
	signal initial : std_logic := '1';

	signal data : std_logic_vector(BITS-1 downto 0);
	signal serial_data : std_logic := '0';
	signal serial_clk : std_logic := '0';
	signal byte_finished, last_byte_finished : std_logic := '0';
	signal bus_cycle : std_logic := '0';

	signal received_data : std_logic_vector(BITS-1 downto 0);

	signal byte_ctr : natural range 0 to 3 := 0;

begin
	-- clock
	clk <= not clk after CLK_DELAY;
	bus_cycle <= byte_finished and (not last_byte_finished);


	-- instantiate modules
	serial_ent : entity work.serial
		generic map(BITS => BITS, SERIAL_CLK_INACTIVE => '0',
			MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ)
		port map(in_clk => clk, in_reset => rst,
			in_enable => start, out_ready => ready,
			out_clk => serial_clk, out_next_word => byte_finished,
			in_parallel => data, out_serial => serial_data,
			in_serial => serial_data, out_parallel => received_data);


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
				data <= int_to_logvec(4, BITS);
			elsif byte_ctr = 3 then
				data <= int_to_logvec(255, BITS);
				start <= '0';
			end if;
		end if;

		if VERBOSE='1' then
			report	lf &
				"clk = " & std_logic'image(clk) &
				", reset: " & std_logic'image(rst) &
				", start: " & std_logic'image(start) &
				", data: " & integer'image(to_int(data)) &
				", received_data: " & integer'image(to_int(received_data)) &
				", next: " & std_logic'image(byte_finished) &
				", cycle: " & std_logic'image(bus_cycle) &
				", serial_clk: " & std_logic'image(serial_clk) &
				", serial_data: " & std_logic'image(serial_data) &
				", byte_ctr: " & integer'image(byte_ctr);
		end if;
	end process;


	serial_proc : process(serial_clk)
	begin
		-- has to be opposite the edge triggers in the serial controller
		--if rising_edge(serial_clk) then
		if falling_edge(serial_clk) then
			report "transmitted data: " & std_logic'image(serial_data) &
				", received data: " & to_hstring(received_data) &
				", next: " & std_logic'image(byte_finished);
		end if;
	end process;

end architecture;
