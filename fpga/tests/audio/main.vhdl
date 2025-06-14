--
-- audio test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 3-may-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;


-- pll freq: SAMPLE_FREQ * FRAME_BITS [= 32] * 2 channels * 4
library audclk_pll;
use audclk_pll.all;



entity main is
	port(
		-- main clock
		clock_50_b7a : in std_logic;

		-- buttons and switches
		key : in std_logic_vector(0 downto 0);
		sw : in std_logic_vector(0 downto 0);

		-- leds
		ledg : out std_logic_vector(7 downto 0);
		ledr : out std_logic_vector(9 downto 0);

		 -- segment displays
		hex0, hex1, hex2, hex3 : out std_logic_vector(6 downto 0);

		-- lcd reset, serial clock and data lines (3-wire serial bus)
		lcd_reset, lcd_scl, lcd_sda : out std_logic;
		lcd_sda_in : in std_logic;

		-- audio interface
		aud_scl, aud_sda : inout std_logic;
		aud_adclrck, aud_daclrck, aud_bclk : out std_logic;  --inout std_logic;
		--aud_adcdat : in std_logic;   -- ADC data, from microphone
		aud_dacdat : out std_logic;  -- DAC data, to speaker
		aud_xck : out std_logic
	);
end entity;



architecture main_impl of main is
	constant FRAME_BITS : natural := 32;
	constant SAMPLE_BITS : natural := 16;
	constant SAMPLE_FREQ : natural := 44_100;

	-- clocks
	constant MAIN_HZ       : natural := 50_000_000;
	constant AUD_SERIAL_HZ : natural := 100_000;
	constant LCD_SERIAL_HZ : natural := 1_000_000;

	-- lcd
	constant LCD_SIZE : natural := 4 * 20;
	constant LCD_WORDBITS : natural := 8;
	constant LCD_ADDRBITS : natural := 7;

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
	signal xclk_locked : std_logic;

	-- lcd
	signal lcd_refresh : std_logic;

	signal lcd_serial_enable, lcd_serial_next, lcd_serial_ready : std_logic;
	signal lcd_serial_data : std_logic_vector(LCD_WORDBITS - 1 downto 0);
	signal lcd_serial_data_in : std_logic_vector(LCD_WORDBITS - 1 downto 0);

	-- slow clocks for debugging
	signal xclk_slow, bitclk_slow, sampleclk_slow : std_logic;

	signal samples_end : std_logic;
	signal amp : std_logic;
	signal tone_hz : std_logic_vector(15 downto 0) := 16d"330";
	signal tone_cycle : std_logic_vector(7 downto 0);
	signal tone_finished : std_logic;

begin

	reset <= not key(0);
	lcd_refresh <= '1';

	-- audio interface
	xclk_lck <= xclk when xclk_locked = '1' else '0';
	aud_xck <= xclk_lck when audio_active = '1' else '0';
	aud_bclk <= bitclk; -- when audio_active = '1' else '0';
	aud_daclrck <= sampleclk; -- when audio_active = '1' else '0';
	aud_adclrck <= '0';

	aud_dacdat <= amp when sw(0) = '0' else '0';


	--------------------------------------------------------------------------------
	-- debugging
	--------------------------------------------------------------------------------
	ledg <= audio_status(7 downto 0);
	ledr(0) <= xclk_slow;
	ledr(1) <= bitclk_slow;
	ledr(2) <= sampleclk_slow;
	ledr(8) <= samples_end;
	ledr(9) <= serial_audio_err;
	ledr(7 downto 3) <= (others => '0');
	--------------------------------------------------------------------------------


	--------------------------------------------------------------------------------
	-- display current tone frequency
	--------------------------------------------------------------------------------
	seg0 : entity work.sevenseg
		 generic map(zero_is_on => '1', inverse_numbering => '1')
		 port map(in_digit => tone_hz(3 downto 0), out_leds => hex0);
	seg1 : entity work.sevenseg
		 generic map(zero_is_on => '1', inverse_numbering => '1')
		 port map(in_digit => tone_hz(7 downto 4), out_leds => hex1);
	seg2 : entity work.sevenseg
		 generic map(zero_is_on => '1', inverse_numbering => '1')
		 port map(in_digit => tone_hz(11 downto 8), out_leds => hex2);
	seg3 : entity work.sevenseg
		 generic map(zero_is_on => '1', inverse_numbering => '1')
		 port map(in_digit => tone_hz(15 downto 12), out_leds => hex3);
	--------------------------------------------------------------------------------


	--------------------------------------------------------------------------------
	-- lcd
	--------------------------------------------------------------------------------
	lcd : entity work.txtlcd_3wire
		generic map(MAIN_CLK => MAIN_HZ, LCD_SIZE => LCD_SIZE)
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_update => lcd_refresh, in_bus_data => lcd_serial_data_in,
			in_bus_next => lcd_serial_next, in_bus_ready => lcd_serial_ready,
			in_tone_cycle => tone_cycle, in_tone_finished => tone_finished,
			--out_busy_flag => ledr,
			out_bus_data => lcd_serial_data, out_bus_enable => lcd_serial_enable,
			out_lcd_reset => lcd_reset);

	-- serial bus for lcd
	serial_lcd : entity work.serial
		generic map(MAIN_HZ => MAIN_HZ, SERIAL_HZ => LCD_SERIAL_HZ, LOWBIT_FIRST => '1')
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_enable => lcd_serial_enable, in_parallel => lcd_serial_data,
			out_next_word => lcd_serial_next, out_ready => lcd_serial_ready,
			out_clk => lcd_scl, out_serial => lcd_sda,
			in_serial => lcd_sda_in, out_parallel => lcd_serial_data_in);
	--------------------------------------------------------------------------------


	--------------------------------------------------------------------------------
	--
	-- generate audio clocks:
	--   xclk = sample_freq * sample_bits * 2 channels * 4
	--   bclk = sample_freq * sample_bits * 2 channels     = xclk / 4
	--   sclk = sample_freq                                = bclk / sample_bits / 2 = xclk / 256
	--
	clkgen_xclk : entity audclk_pll.audclk_pll
		port map(refclk => clock_50_b7a, rst => reset, outclk_0 => xclk, locked => xclk_locked);

	clkgen_bitclk : entity work.clkdiv(clkdiv_impl)
		generic map(USE_RISING_EDGE => '1', NUM_CTRBITS => 2, SHIFT_BITS => 1)
		port map(in_clk => xclk_lck, in_rst => reset, out_clk => bitclk);

	clkgen_sampleclk : entity work.clkctr
		generic map(USE_RISING_EDGE => '0', COUNTER => FRAME_BITS, CLK_INIT => '0')
		port map(in_clk => bitclk, in_reset => reset, out_clk => sampleclk);

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
	--------------------------------------------------------------------------------


	--------------------------------------------------------------------------------
	-- audio
	--------------------------------------------------------------------------------
	--
	-- audio configuration serial interface
	--
	audio_serial : entity work.serial_2wire
		generic map(MAIN_HZ => MAIN_HZ, SERIAL_HZ => AUD_SERIAL_HZ,
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

	--
	-- audio configuration
	--
	audio_cfg : entity work.audio_cfg
		generic map(MAIN_CLK => MAIN_HZ,
			BUS_ADDRBITS => SERIAL_ADDRBITS, BUS_DATABITS => SERIAL_DATABITS,
			BUS_WRITEADDR => SERIAL_AUDIO_WRITE_ADDR, BUS_READADDR => SERIAL_AUDIO_READ_ADDR,
			SAMPLE_BITS => SAMPLE_BITS)
		port map(in_clk => clock_50_b7a, in_reset => reset,
			in_bus_ready => serial_audio_ready,
			out_bus_enable => serial_audio_enable, in_bus_byte_finished => serial_audio_byte_finished,
			out_bus_data => serial_audio_data_write, in_bus_data => serial_audio_data_read,
			out_bus_addr => serial_audio_addr, out_active => audio_active, out_status => audio_status);
	--------------------------------------------------------------------------------


	--------------------------------------------------------------------------------
	-- tones
	--------------------------------------------------------------------------------
	--
	-- tone generation
	--
	audio_gen : entity work.audio
		generic map(TONE_BITS => tone_hz'length, FRAME_BITS => FRAME_BITS,
			SAMPLE_BITS => SAMPLE_BITS, SAMPLE_FREQ => SAMPLE_FREQ)
		port map(in_reset => reset, --in_freqsel => not key(1),
			in_bitclk => bitclk, in_sampleclk => sampleclk,
			in_tone_hz => tone_hz,
			out_data => amp, out_samples_end => samples_end);


	--
	-- tone sequence
	--
	tone_seq : entity work.tones
		generic map(MAIN_HZ => SAMPLE_FREQ, FREQ_BITS => tone_hz'length)
		port map(in_clk => sampleclk, in_reset => reset,
			in_enable => audio_active, out_freq => tone_hz,
			out_cycle => tone_cycle, out_finished => tone_finished);
	--------------------------------------------------------------------------------


end architecture;
