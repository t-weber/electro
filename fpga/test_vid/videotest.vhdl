--
-- video test
-- @author Tobias Weber
-- @data apr-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;

library pixclk_pll;
use pixclk_pll.all;



entity videotest is
	generic(
		-- clocks
		MAIN_HZ   : natural := 50_000_000;
		SERIAL_HZ : natural := 400_000;

		-- serial bus addresses
		SERIAL_VID_WRITE_ADDR : std_logic_vector(7 downto 0) := x"72";
		SERIAL_VID_READ_ADDR  : std_logic_vector(7 downto 0) := x"73"
	);

	port(
		-- main clock
		clock50 : in std_logic;

		-- video control interface
		vid_scl, vid_sda : inout std_logic;

		-- video interface
		vid_tx_int : in std_logic;
		vid_tx_hs, vid_tx_vs, vid_tx_de : out std_logic;
		vid_tx_clk : out std_logic;
		vid_tx_d : out std_logic_vector(23 downto 0);

		-- buttons, switches, and leds
		key : in std_logic_vector(0 downto 0);
		sw : in std_logic_vector(0 downto 0);
		ledr : out std_logic_vector(4 downto 0)
	);
end videotest;



architecture videotest_impl of videotest is
	signal reset : std_logic := '0';

	-- serial interface
	signal serial_vid_data_write : std_logic_vector(7 downto 0) := (others => '0');
	signal serial_vid_data_read : std_logic_vector(7 downto 0) := (others => '0');
	signal serial_vid_addr : std_logic_vector(7 downto 0) := (others => '0');
	signal serial_vid_err, serial_vid_busy, serial_vid_enable : std_logic := '0';
	signal vid_active : std_logic := '0';

	-- pixel clock (via pll)
	signal pixel_clk, pixel_clk_locked : std_logic := '0';
	signal test_clk : std_logic := '0';

	-- video signal
	signal vid_x : std_logic_vector(10 downto 0) := (others => '0');
	signal vid_y : std_logic_vector(9 downto 0) := (others => '0');

	-- text output
	signal tile_num : std_logic_vector(11 downto 0) := (others => '0');
	signal tile_pix_x : std_logic_vector(3 downto 0) := (others => '0');
	signal tile_pix_y : std_logic_vector(4 downto 0) := (others => '0');
	signal cur_char : std_logic_vector(7 downto 0) := (others => '0');


begin

	reset <= not key(0);
	ledr(0) <= serial_vid_err;
	ledr(1) <= serial_vid_busy;
	ledr(2) <= pixel_clk_locked;
	ledr(3) <= test_clk;
	ledr(4) <= vid_active;

	----------------------------------------------------------------------------
	-- clocks
	----------------------------------------------------------------------------
	-- slow test clock
	clktest : entity work.clkgen
		generic map(MAIN_HZ => 74250000, CLK_HZ => 1)
		port map(in_clk => pixel_clk, in_reset => not pixel_clk_locked,
			out_clk => test_clk);

	-- 74.25 MHz clock via pll
	pixclk_pll_inst : entity pixclk_pll.pixclk_pll
		port map (refclk => clock50, rst => reset,
			outclk_0 => pixel_clk, locked => pixel_clk_locked);
	----------------------------------------------------------------------------

	----------------------------------------------------------------------------
	-- video configuration
	----------------------------------------------------------------------------
	vid_serial : entity work.serial2wire_ctrl
		generic map(MAIN_CLK => MAIN_HZ, SERIAL_CLK => SERIAL_HZ)
		port map(clk => clock50, rst => reset, enable => serial_vid_enable,
			addr => serial_vid_addr(7 downto 1), rw => serial_vid_addr(0),
			data_rd => serial_vid_data_read, data_wr => serial_vid_data_write,
			err => serial_vid_err, busy => serial_vid_busy,
			scl => vid_scl, sda => vid_sda);

	vid_cfg : entity work.video_cfg
		generic map(MAIN_CLK => MAIN_HZ,
			BUS_WRITEADDR => SERIAL_VID_WRITE_ADDR, BUS_READADDR => SERIAL_VID_READ_ADDR)
		port map(in_clk => clock50, in_reset => reset,
			in_bus_busy => serial_vid_busy, in_bus_error => serial_vid_err,
			in_int => vid_tx_int,
			out_bus_enable => serial_vid_enable,
			out_bus_data => serial_vid_data_write, in_bus_data => serial_vid_data_read,
			out_bus_addr => serial_vid_addr,
			out_active => vid_active);
	----------------------------------------------------------------------------

	----------------------------------------------------------------------------
	-- video signal generation
	----------------------------------------------------------------------------
	vid : entity work.video
		generic map(
			HSYNC_START => 110, HSYNC_STOP => 110 + 40, HSYNC_DELAY => 110 + 40 + 220,
			VSYNC_START => 5,   VSYNC_STOP => 5 + 5,    VSYNC_DELAY => 5 + 5 + 20,
			HPIX_VISIBLE => 1280, HPIX_TOTAL => 1280 + 110 + 40 + 220,
			VPIX_VISIBLE => 720,  VPIX_TOTAL => 720 + 5 + 5 + 20)
		port map(in_clk => pixel_clk, in_rst => not pixel_clk_locked,
			in_mem => (others => '0'), in_testpattern => sw(0),
			out_hsync => vid_tx_hs, out_vsync => vid_tx_vs,
			out_pixel_enable => vid_tx_de,
			out_pixel => vid_tx_d, out_hpix => vid_x, out_vpix => vid_y);

	vid_tx_clk <= not pixel_clk;

	-- text output
	tile_ent : entity work.tile
		generic map(
			SCREEN_WIDTH => 1280, SCREEN_HEIGHT => 720,
			TILE_WIDTH => 16, TILE_HEIGHT => 24)
		port map(
			in_x => vid_x, in_y => vid_y,
			out_tile_num => tile_num,
			out_tile_pix_x => tile_pix_x, out_tile_pix_y => tile_pix_y);

	txt_rom : entity work.textrom
		generic map(NUM_PORTS => 1)
		port map(in_addr(0) => tile_num, out_data(0) => cur_char);

	-- TODO: font rom
	----------------------------------------------------------------------------

end videotest_impl;
