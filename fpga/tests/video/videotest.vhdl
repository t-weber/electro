--
-- video test
-- @author Tobias Weber
-- @data apr-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;

library pixclk_pll;
use pixclk_pll.all;



entity videotest is
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
		key : in std_logic_vector(1 downto 0);
		sw : in std_logic_vector(0 downto 0);
		ledr : out std_logic_vector(4 downto 0)
	);
end videotest;



architecture videotest_impl of videotest is
	----------------------------------------------------------------------------
	-- constants
	----------------------------------------------------------------------------
	-- clocks
	constant MAIN_HZ   : natural := 50_000_000;
	constant SERIAL_HZ : natural := 400_000;

	-- synchronisation signals
	constant HSYNC_START : natural := 110;
	constant HSYNC_STOP : natural := HSYNC_START + 40;
	constant HSYNC_DELAY : natural := HSYNC_STOP + 220;
	constant VSYNC_START : natural := 5;
	constant VSYNC_STOP : natural := VSYNC_START + 5;
	constant VSYNC_DELAY : natural := VSYNC_STOP + 20;

	-- screen dimensions
	constant SCREEN_WIDTH : natural := 1280;
	constant SCREEN_HEIGHT : natural := 720;

	-- text tiles
	constant TEXT_TILE_WIDTH : natural := 16;
	constant TEXT_TILE_HEIGHT : natural := 24;
	constant NUM_TEXT_ROWS : natural := 30;
	constant NUM_TEXT_COLS : natural := 80;

	-- serial bus addresses
	constant SERIAL_VID_WRITE_ADDR : std_logic_vector(7 downto 0) := x"72";
	constant SERIAL_VID_READ_ADDR  : std_logic_vector(7 downto 0) := x"73";
	----------------------------------------------------------------------------

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
	signal cur_fgcol : std_logic_vector(8*3-1 downto 0) := (others => '1');
	signal cur_bgcol : std_logic_vector(8*3-1 downto 0) := (others => '0');
	signal cur_col : std_logic_vector(8*3-1 downto 0) := (others => '0');
	signal font_pixel : std_logic := '0';

	-- writing to text memory
	signal char_to_write : std_logic_vector(7 downto 0) := (others => '0');
	signal char_to_write_stable : std_logic_vector(7 downto 0) := (others => '0');
	signal write_char : std_logic := '0';

begin

	reset <= not key(0);
	write_char <= not key(1);

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
	-- serial bus
	vid_serial : entity work.serial2wire_ctrl
		generic map(MAIN_CLK => MAIN_HZ, SERIAL_CLK => SERIAL_HZ)
		port map(clk => clock50, rst => reset, enable => serial_vid_enable,
			addr => serial_vid_addr(7 downto 1), rw => serial_vid_addr(0),
			data_rd => serial_vid_data_read, data_wr => serial_vid_data_write,
			err => serial_vid_err, busy => serial_vid_busy,
			scl => vid_scl, sda => vid_sda);

	-- configuration
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
	-- video controller
	vid : entity work.video
		generic map(
			HSYNC_START => HSYNC_START, HSYNC_STOP => HSYNC_STOP, HSYNC_DELAY => HSYNC_DELAY,
			VSYNC_START => VSYNC_START, VSYNC_STOP => VSYNC_STOP, VSYNC_DELAY => VSYNC_DELAY,
			HPIX_VISIBLE => SCREEN_WIDTH,  HPIX_TOTAL => SCREEN_WIDTH + HSYNC_DELAY,
			VPIX_VISIBLE => SCREEN_HEIGHT, VPIX_TOTAL => SCREEN_HEIGHT + VSYNC_DELAY)
		port map(in_clk => pixel_clk, in_rst => reset or not pixel_clk_locked,
			in_mem => cur_col, --(others => font_pixel),
			in_testpattern => sw(0),
			out_hsync => vid_tx_hs, out_vsync => vid_tx_vs,
			out_pixel_enable => vid_tx_de,
			out_pixel => vid_tx_d, out_hpix => vid_x, out_vpix => vid_y);

	-- pixel clock
	vid_tx_clk <= pixel_clk; --when pixel_clk_locked = '1' else '0';

	-- --calculate character tiles for text output
	tile_ent : entity work.tile
		generic map(SCREEN_WIDTH => SCREEN_WIDTH, SCREEN_HEIGHT => SCREEN_HEIGHT,
			TILE_WIDTH => TEXT_TILE_WIDTH, TILE_HEIGHT => TEXT_TILE_HEIGHT)
		port map(in_x => vid_x, in_y => vid_y,
			out_tile_num => tile_num,
			out_tile_pix_x => tile_pix_x, out_tile_pix_y => tile_pix_y);

	-- text buffer in rom
	--txt_rom : entity work.textrom
	--	generic map(NUM_PORTS => 1)
	--	port map(in_addr(0) => tile_num, out_data(0) => cur_char);

	-- text buffer in ram
	txt_ram : entity work.ram
		generic map(NUM_PORTS => 2, NUM_WORDS => NUM_TEXT_ROWS * NUM_TEXT_COLS,
			ADDR_BITS => 12, WORD_BITS => 8)
		port map(in_clk => pixel_clk, in_rst => reset,
			-- port 0
			in_addr(0) => tile_num, out_data(0) => cur_char,
			in_read_ena(0) => '1', in_write_ena(0) => '0',
			in_data(0) => (others => '0'),
			-- port 1
			in_addr(1) => int_to_logvec(15*80 + 40, 12),
			in_read_ena(1) => '0', in_write_ena(1) => write_char,
			in_data(1) => char_to_write_stable);

	-- text foreground colour
	txt_fgram : entity work.ram
		generic map(NUM_PORTS => 1, NUM_WORDS => NUM_TEXT_ROWS * NUM_TEXT_COLS,
			ADDR_BITS => 12, WORD_BITS => 3*8)
		port map(in_clk => pixel_clk, in_rst => reset,
			in_addr(0) => tile_num, out_data(0) => cur_fgcol,
			in_read_ena(0) => '1', in_write_ena(0) => '0',
			in_data(0) => (others => '0'));

	-- text background colour
	txt_bgram : entity work.ram
		generic map(NUM_PORTS => 1, NUM_WORDS => NUM_TEXT_ROWS * NUM_TEXT_COLS,
			ADDR_BITS => 12, WORD_BITS => 3*8)
		port map(in_clk => pixel_clk, in_rst => reset,
			in_addr(0) => tile_num, out_data(0) => cur_bgcol,
			in_read_ena(0) => '1', in_write_ena(0) => '0',
			in_data(0) => (others => '0'));

	-- font rom; generate with:
	--   ./genfont -h 24 -w 24 --target_height 24 --target_pitch 2 -t vhdl -o font.vhdl
	font_rom : entity work.font
		port map(in_char => cur_char(6 downto 0),
			in_x => tile_pix_x, in_y => tile_pix_y,
			out_pixel => font_pixel);

	-- current pixel colour
	cur_col <= cur_fgcol when font_pixel = '1' else cur_bgcol;

	----------------------------------------------------------------------------

	-- data synchronisation for writing in text memory
	txt_clk_sync : entity work.clksync
		generic map(BITS => 8, FLIPFLOPS => 2)
		port map(in_clk => pixel_clk, in_rst => reset,
			in_data => char_to_write, out_data => char_to_write_stable);

	-- char to write to memory
	char_to_write <= x"41";

	----------------------------------------------------------------------------

end videotest_impl;
