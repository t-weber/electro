--
-- serial seven segment display test
-- @author Tobias Weber
-- @date 15-nov-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity sevenseg_test is
	port(
		-- main clock
		clk27 : in std_logic;

		-- buttons and leds
		key : in std_logic_vector(1 downto 0);
		btn : in std_logic_vector(0 downto 0);
		led : out std_logic_vector(5 downto 0);

		-- led matrix
		seg_dat, seg_sel, seg_clk : out std_logic
	);
end entity;



architecture sevenseg_test_impl of sevenseg_test is
	constant MAIN_CLK_HZ    : natural := 27_000_000;
	constant SERIAL_CLK_HZ  : natural :=  2_000_000;
	constant SLOW_CLK_HZ    : natural :=         10;

	constant SERIAL_BITS    : natural := 16;
	constant CTR_BITS       : natural := 24;
	constant BCD_CTR_DIGITS : natural := 8;

	-- keys
	signal rst, stop_update, show_hex : std_logic;

	-- led matrix serial bus
	signal serial_enable : std_logic := '1';
	signal serial_ready, serial_next_word : std_logic;
	signal serial_in_parallel : std_logic_vector(SERIAL_BITS - 1 downto 0);

	-- led matrix interface
	signal update_leds : std_logic;
	signal displayed_ctr : std_logic_vector(BCD_CTR_DIGITS*4 - 1 downto 0);

	-- slow clock
	signal slow_clk : std_logic;

	-- counter
	signal ctr : std_logic_vector(CTR_BITS - 1 downto 0);

	-- bcd conversion
	signal bcd_finished : std_logic;
	signal bcd_ctr : std_logic_vector(BCD_CTR_DIGITS*4 - 1 downto 0);

begin
	-- ---------------------------------------------------------------------------
	--  keys
	-- ---------------------------------------------------------------------------
	debounce_key0 : entity work.debounce(debounce_switch_impl)
		port map(in_clk => clk27, in_rst => '0', in_signal => not key(0), out_debounced => rst);

	debounce_key1 : entity work.debounce(debounce_button_impl)
		port map(in_clk => clk27, in_rst => rst, in_signal => not key(1), out_toggled => stop_update);

	debounce_btn0 : entity work.debounce(debounce_button_impl)
		generic map(STABLE_TICKS => 50)
		port map(in_clk => clk27, in_rst => rst, in_signal => not btn(0), out_toggled => show_hex);
	-- ---------------------------------------------------------------------------


	-- ---------------------------------------------------------------------------
	-- led matrix serial bus
	-- ---------------------------------------------------------------------------
	serial_mod : entity work.serial_tx
		generic map(BITS => SERIAL_BITS, LOWBIT_FIRST => '0', USE_FALLING_EDGE => '0',
			MAIN_HZ => MAIN_CLK_HZ, SERIAL_HZ => SERIAL_CLK_HZ,
			SERIAL_CLK_INACTIVE => '0', SERIAL_DATA_INACTIVE => '0')
		port map(in_clk => clk27, in_reset => rst,
			in_enable => serial_enable, out_ready => serial_ready,
			out_clk => seg_clk, out_serial => seg_dat,
			in_parallel => serial_in_parallel, out_next_word => serial_next_word);
	-- ---------------------------------------------------------------------------


	-- ---------------------------------------------------------------------------
	-- led matrix interface
	-- ---------------------------------------------------------------------------
	ledmatrix_mod : entity work.ledmatrix
		generic map(MAIN_CLK => MAIN_CLK_HZ, BUS_BITS => SERIAL_BITS,
			NUM_SEGS => 8, LEDS_PER_SEG => 8, TRANSPOSE => '1')
		port map(in_clk => clk27, in_rst => rst,
			in_update => update_leds, in_digits => displayed_ctr,
			in_bus_ready => serial_ready, in_bus_next_word => serial_next_word,
			out_bus_enable => serial_enable, out_bus_data => serial_in_parallel,
			out_seg_enable => seg_sel);

	update_leds <= not stop_update when show_hex = '1' else bcd_finished and not stop_update;
	displayed_ctr <= std_logic_vector'(
		(displayed_ctr'length - ctr'length - 1 downto 0 => '0') & ctr)
		when show_hex = '1' else bcd_ctr;
	-- ---------------------------------------------------------------------------


	-- ---------------------------------------------------------------------------
	-- slow clock
	-- ---------------------------------------------------------------------------
	clk_slow : entity work.clkgen
		generic map(MAIN_HZ => MAIN_CLK_HZ, CLK_HZ => SLOW_CLK_HZ)
		port map(in_clk => clk27, in_reset => rst, out_clk => slow_clk);
	-- ---------------------------------------------------------------------------


	-- ---------------------------------------------------------------------------
	-- counter
	-- ---------------------------------------------------------------------------
	ctr_proc : process(slow_clk, rst) begin
		if rst = '1' then
			ctr <= (others => '0');
		elsif rising_edge(slow_clk) then
			ctr <= inc_logvec(ctr, 1);
		end if;
	end process;
	-- ---------------------------------------------------------------------------


	-- ---------------------------------------------------------------------------
	-- bcd conversion
	-- ---------------------------------------------------------------------------
	bcd_mod : entity work.bcd
		generic map(IN_BITS => CTR_BITS, OUT_BITS => BCD_CTR_DIGITS*4, NUM_BCD_DIGITS => BCD_CTR_DIGITS)
		port map(in_clk => clk27, in_rst => rst,
			in_num => ctr, out_bcd => bcd_ctr,
			in_start => '1', out_finished => bcd_finished);
	-- ---------------------------------------------------------------------------


	-- ---------------------------------------------------------------------------
	-- status outputs
	-- ---------------------------------------------------------------------------
	led(0) <= not serial_ready;
	led(1) <= not stop_update;
	led(2) <= not show_hex;
	led(3) <= btn(0);
	led(4) <= slow_clk;
	led(5) <= '1';
	-- ---------------------------------------------------------------------------

end architecture;
