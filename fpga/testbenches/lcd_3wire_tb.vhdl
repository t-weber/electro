--
-- lcd and serial controller testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 2-dec-2023
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  &&  ghdl -a --std=08 ../lib/lcd_3wire.vhdl  &&  ghdl -a --std=08 ../lib/serial.vhdl  &&  ghdl -a --std=08 lcd_3wire_tb.vhdl  &&  ghdl -e --std=08 lcd_3wire_tb lcd_3wire_tb_arch
-- ghdl -r --std=08 lcd_3wire_tb lcd_3wire_tb_arch --vcd=lcd_3wire_tb.vcd --stop-time=5000ns
-- gtkwave lcd_3wire_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity lcd_3wire_tb is
end entity;


architecture lcd_3wire_tb_arch of lcd_3wire_tb is
	constant PRINT_CLK : std_logic := '0';
	constant PRINT_SERIAL_CLK : std_logic := '1';

	constant MAIN_HZ : natural := 40_000_000;
	constant SERIAL_HZ : natural := 20_000_000;
	constant BITS : natural := 8;

	constant CLK_DELAY : time := 20 ns;
	signal clk, rst : std_logic := '0';

	signal serial_data : std_logic := '0';
	signal serial_clk : std_logic := '0';
	signal nextbyte : std_logic := '0';
	signal ready : std_logic := '0';

	signal bus_enable : std_logic;
	signal bus_data : std_logic_vector(BITS-1 downto 0);

begin
	-- clock
	clk <= not clk after CLK_DELAY;


	-- instantiate modules
	serial_ent : entity work.serial
		generic map(BITS => BITS, MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ)
		port map(in_clk => clk, in_reset => rst,
			in_enable => bus_enable, in_parallel => bus_data,
			out_clk => serial_clk, out_serial => serial_data,
			out_next_word => nextbyte, out_ready => ready);

	lcd_ent : entity work.lcd_3wire
		generic map(main_clk => MAIN_HZ, bus_num_databits => BITS)
		port map(in_clk => clk, in_reset => rst, in_update => '1',
			in_bus_next => nextbyte, in_bus_ready => ready,
			out_bus_enable => bus_enable, out_bus_data => bus_data,
			in_mem_word => "00000000");


	clk_proc : process(clk)
	begin
		if PRINT_CLK='1' then
			report lf &
				"clk = " & std_logic'image(clk) &
				", ready: " & std_logic'image(ready) &
				", nextbyte: " & std_logic'image(nextbyte) &
				", serial_clk: " & std_logic'image(serial_clk) &
				", serial_data: " & std_logic'image(serial_data) &
				", bus_data: " & to_hstring(bus_data) &
				", bus_enable: " & std_logic'image(bus_enable);
		end if;
	end process;


	serial_clk_proc : process(serial_clk)
	begin
		if PRINT_SERIAL_CLK='1' and rising_edge(serial_clk) then
			report "serial_data: " & std_logic'image(serial_data);
		end if;
	end process;

end architecture;
