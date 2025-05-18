--
-- audio test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 3-may-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;

-- freq: SAMPLE_FREQ * SAMPLE_BITS * 4 * 4
library audclk_pll;
use audclk_pll.all;

-- freq: SAMPLE_FREQ * (SAMPLE_BITS + 2) * 2
--library bitclk_pll;
--use bitclk_pll.all;



entity main is
	port(
		clock_50_b7a : in std_logic;

		key : in std_logic_vector(3 downto 0);
		--sw : in std_logic_vector(7 downto 0);

		ledg : out std_logic_vector(7 downto 0);
		ledr : out std_logic_vector(9 downto 0);

		aud_scl, aud_sda : inout std_logic;
		aud_adclrck, aud_daclrck, aud_bclk : out std_logic;  --inout std_logic;
		--aud_adcdat : in std_logic;   -- ADC data, from microphone
		aud_dacdat : out std_logic;  -- DAC data, to speaker
		aud_xck : out std_logic
	);
end entity;



architecture main_impl of main is
	constant SAMPLE_BITS : natural := 16;
	constant SAMPLE_FREQ : natural := 44_100;

	-- clocks
	constant MAIN_HZ   : natural := 50_000_000;
	constant SERIAL_HZ : natural := 100_000;
	--constant AUDIO_HZ  : natural := SAMPLE_FREQ * SAMPLE_BITS * 4 * 4;

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

	-- clocks
	signal xclk, xclk_lck, bitclk, sampleclk : std_logic;
	signal xclk_locked, bitclk_locked : std_logic;
	-- slow clocks for debugging
	signal xclk_slow, bitclk_slow, sampleclk_slow : std_logic;

	signal samples_end : std_logic;

begin

	reset <= not key(0);
	xclk_lck <= xclk when xclk_locked = '1' else '0';
	aud_xck <= xclk_lck when audio_active = '1' else '0';
	aud_bclk <= bitclk; --when audio_active = '1' else '0';
	aud_daclrck <= sampleclk; --when audio_active = '1' else '0';
	aud_adclrck <= '0';

	-- debugging
	ledg <= audio_status(7 downto 0);
	ledr(0) <= xclk_slow;
	ledr(1) <= bitclk_slow;
	ledr(2) <= sampleclk_slow;
	ledr(8) <= samples_end;
	ledr(9) <= serial_audio_err;
	ledr(7 downto 3) <= (others => '0');

	-- generate audio clocks
	clkgen_xclk : entity audclk_pll.audclk_pll
		port map(refclk => clock_50_b7a, rst => reset, outclk_0 => xclk, locked => xclk_locked);

	--clkgen_xclk : entity work.clkgen
	--	generic map(MAIN_HZ => MAIN_HZ, CLK_HZ => AUDIO_HZ, CLK_INIT => '1')
	--	port map(in_clk => clock_50_b7a, in_reset => reset, out_clk => xclk);

	clkgen_bitclk : entity work.clkdiv(clkdiv_impl)
		generic map(USE_RISING_EDGE => '1', NUM_CTRBITS => 3, SHIFT_BITS => 2)
		port map(in_clk => xclk_lck, in_rst => reset, out_clk => bitclk);

	--clkgen_bitclk : entity bitclk_pll.bitclk_pll
	--	port map(refclk => clock_50_b7a, rst => reset, outclk_0 => bitclk, locked => bitclk_locked);

	clkgen_sampleclk : entity work.clkdiv(clkdiv_impl)
		generic map(USE_RISING_EDGE => '1', NUM_CTRBITS => 5, SHIFT_BITS => 4)  -- SHIFT_BITS => ceil(log2(SAMPLE_BITS))
		port map(in_clk => bitclk, in_rst => reset, out_clk => sampleclk);

	--clkgen_sampleclk : entity work.clkctr
	--	generic map(USE_RISING_EDGE => '1', COUNTER => SAMPLE_BITS, CLK_INIT => '0')
	--	port map(in_clk => bitclk, in_reset => reset, out_clk => sampleclk);

	--clkgen_sampleclk : entity work.clkdiv(clkdiv_impl)
	--	generic map(USE_RISING_EDGE => '1', NUM_CTRBITS => 8, SHIFT_BITS => 7)
	--	port map(in_clk => xclk_lck, in_rst => reset, out_clk => sampleclk);

	-- generate slow clocks for debugging
	clkgen_slowxclk : entity work.clkdiv(clkdiv_impl)
		generic map(NUM_CTRBITS => 21, SHIFT_BITS => 20)
		port map(in_clk => xclk_lck, in_rst => reset, out_clk => xclk_slow);

	clkgen_slowbitclk : entity work.clkdiv(clkdiv_impl)
		generic map(NUM_CTRBITS => 21, SHIFT_BITS => 20)
		port map(in_clk => bitclk, in_rst => reset, out_clk => bitclk_slow);

	clkgen_slowchclk : entity work.clkdiv(clkdiv_impl)
		generic map(NUM_CTRBITS => 21, SHIFT_BITS => 20)
		port map(in_clk => sampleclk, in_rst => reset, out_clk => sampleclk_slow);

	-- audio configuration serial interface
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

	  -- audio configuration
	audio_cfg : entity work.audio_cfg
		generic map(MAIN_CLK => MAIN_HZ,
			BUS_ADDRBITS => SERIAL_ADDRBITS, BUS_DATABITS => SERIAL_DATABITS,
			BUS_WRITEADDR => SERIAL_AUDIO_WRITE_ADDR, BUS_READADDR => SERIAL_AUDIO_READ_ADDR)
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_bus_ready => serial_audio_ready,
			out_bus_enable => serial_audio_enable, in_bus_byte_finished => serial_audio_byte_finished,
			out_bus_data => serial_audio_data_write, in_bus_data => serial_audio_data_read,
			out_bus_addr => serial_audio_addr, out_active => audio_active, out_status => audio_status);

	-- audio generation
	audio_gen : entity work.audio
		generic map(SAMPLE_BITS => SAMPLE_BITS, SAMPLE_FREQ => SAMPLE_FREQ)
		port map(in_reset => reset, in_freqsel => not key(1),
			in_bitclk => bitclk, in_channelclk => sampleclk,
			out_data => aud_dacdat, out_samples_end => samples_end);

end architecture;
