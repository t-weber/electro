--
-- serial controller testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-nov-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 conv.vhdl  &&  ghdl -a --std=08 serial.vhdl  &&  ghdl -a --std=08 serial_tb.vhdl  &&  ghdl -e --std=08 serial_tb serial_tb_arch
-- ghdl -r --std=08 serial_tb serial_tb_arch --vcd=serial_tb.vcd --stop-time=2000ns
-- gtkwave serial_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity serial_tb is
end entity;


architecture serial_tb_arch of serial_tb is
	constant MAIN_HZ : natural := 40_000_000;
	constant SERIAL_HZ : natural := 20_000_000;
	constant BITS : natural := 8;

	constant clk_delay : time := 20 ns;
	signal clk, rst : std_logic := '0';

	signal start, finished : std_logic := '0';
	signal initial : std_logic := '1';

	signal data : std_logic_vector(BITS-1 downto 0);
	signal serial_data : std_logic := '0';
	signal serial_clk : std_logic := '0';
	signal busy, last_busy : std_logic := '0';
	signal bus_cycle : std_logic := '0';

begin
	-- clock
	clk <= not clk after clk_delay when finished = '0';
	bus_cycle <= (not busy) and last_busy;


	-- instantiate modules
	serial_ent : entity work.serial
		generic map(BITS => BITS, MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ)
		port map(in_clk => clk, in_reset => rst,
			in_enable => start, in_parallel => data,
			out_clk => serial_clk, out_serial => serial_data,
			out_busy => busy);


	sim : process(clk)
		variable byte_ctr : natural range 0 to 2 := 0;
	begin
		--if rising_edge(clk) then
			last_busy <= busy;
		--end if;

		-- next byte to transmit
		if bus_cycle = '1' then
			byte_ctr := byte_ctr + 1;
		end if;

		if initial = '1' then
			start <= '0';
			rst <= '1';
			byte_ctr := 0;
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
			data <= int_to_logvec(255, BITS);
			start <= '0';
		end if;

		report	lf &
			"clk = " & std_logic'image(clk) &
			", reset: " & std_logic'image(rst) &
			", start: " & std_logic'image(start) &
			", data: " & integer'image(to_int(data)) &
			", busy: " & std_logic'image(busy) &
			", cycle: " & std_logic'image(bus_cycle) &
			", serial_clk: " & std_logic'image(serial_clk) &
			", serial_data: " & std_logic'image(serial_data) &
			", byte_ctr: " & integer'image(byte_ctr);
	end process;

end architecture;
