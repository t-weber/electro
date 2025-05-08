--
-- audio test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 3-may-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;



entity main is
	port(
		clock_50_b7a : in std_logic;

		key : in std_logic_vector(3 downto 0);
		sw : in std_logic_vector(7 downto 0);

		ledg, ledr : out std_logic_vector(7 downto 0);

		aud_scl, aud_sda : inout std_logic;
		aud_adclrck, aud_daclrck, aud_bclk : inout std_logic;
		aud_adcdat : in std_logic;
		aud_dacdat : out std_logic;
		aud_xck : out std_logic
	);
end entity;



architecture main_impl of main is
	-- clocks
	constant MAIN_HZ   : natural := 50_000_000;
	constant SERIAL_HZ : natural := 100_000;

	-- serial bus addresses
	constant SERIAL_ADDRBITS : natural := 8;
	constant SERIAL_DATABITS : natural := 8;
	constant SERIAL_AUDIO_WRITE_ADDR : std_logic_vector(SERIAL_ADDRBITS - 1 downto 0) := x"34";
	constant SERIAL_AUDIO_READ_ADDR  : std_logic_vector(SERIAL_ADDRBITS - 1 downto 0) := x"35";

	signal reset : std_logic := '0';

	-- serial interface
	signal serial_audio_data_write : std_logic_vector(SERIAL_DATABITS - 1 downto 0) := (others => '0');
	signal serial_audio_data_read : std_logic_vector(SERIAL_DATABITS - 1 downto 0) := (others => '0');
	signal serial_audio_addr : std_logic_vector(7 downto 0) := (others => '0');
	signal serial_audio_ready, serial_audio_byte_finished : std_logic := '0';
	signal serial_audio_err, serial_audio_enable : std_logic := '0';
	signal audio_active : std_logic := '0';
	signal audio_status : std_logic_vector(SERIAL_DATABITS - 1 downto 0);

begin

	reset <= not key(0);
	ledg <= audio_status(7 downto 0);
	ledr <= (others => '0');

	audio_serial : entity work.serial_2wire
		generic map(MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ,
			ADDR_BITS => SERIAL_ADDRBITS, BITS => SERIAL_DATABITS)
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_enable => serial_audio_enable,
			in_addr_write => SERIAL_AUDIO_WRITE_ADDR,
			in_addr_read => SERIAL_AUDIO_READ_ADDR,
			in_write => not serial_audio_addr(0),
			in_parallel => serial_audio_data_write, out_parallel => serial_audio_data_read,
			out_err => serial_audio_err, out_ready => serial_audio_ready,
			out_next_word => serial_audio_byte_finished,
			inout_clk => aud_scl, inout_serial => aud_sda);

	  -- configuration
	  audio_cfg : entity work.audio_cfg
		generic map(MAIN_CLK => MAIN_HZ,
			BUS_ADDRBITS => SERIAL_ADDRBITS, BUS_DATABITS => SERIAL_DATABITS,
			BUS_WRITEADDR => SERIAL_AUDIO_WRITE_ADDR, BUS_READADDR => SERIAL_AUDIO_READ_ADDR)
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_bus_ready => serial_audio_ready,
			out_bus_enable => serial_audio_enable, in_bus_byte_finished => serial_audio_byte_finished,
			out_bus_data => serial_audio_data_write, in_bus_data => serial_audio_data_read,
			out_bus_addr => serial_audio_addr, out_active => audio_active, out_status => audio_status);

end architecture;
