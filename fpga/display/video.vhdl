--
-- video
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date jan-2021, mar-2024
-- @license see 'LICENSE' file
--
-- references:
--   - https://www.digikey.com/eewiki/pages/viewpage.action?pageId=15925278
--   - https://academic.csuohio.edu/chu_p/rtl/sopc_vhdl.html
--   - https://www.analog.com/media/en/technical-documentation/user-guides/ADV7513_Programming_Guide.pdf
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;



entity video is
	generic(
		-- colour channels
		-- number of bits in one colour channel
		constant NUM_COLOUR_BITS : natural := 8;
		-- number of bits in all colour channels
		constant NUM_PIXEL_BITS : natural := 3 * NUM_COLOUR_BITS;

		-- rows
		constant HSYNC_START  : natural := 110;              -- 88;
		constant HSYNC_STOP   : natural := HSYNC_START + 40; -- HSYNC_START + 44;
		constant HSYNC_DELAY  : natural := HSYNC_STOP + 220; -- HSYNC_STOP + 148;
		constant HPIX_VISIBLE : natural := 1280;             -- 1920;
		constant HPIX_TOTAL   : natural := HPIX_VISIBLE + HSYNC_DELAY;

		-- columns
		constant VSYNC_START  : natural := 5;                -- 4;
		constant VSYNC_STOP   : natural := VSYNC_START + 5;  -- VSYNC_START + 5;
		constant VSYNC_DELAY  : natural := VSYNC_STOP + 20;  -- VSYNC_STOP + 36;
		constant VPIX_VISIBLE : natural := 720;              -- 1080;
		constant VPIX_TOTAL   : natural := VPIX_VISIBLE + VSYNC_DELAY;

		-- counter bits
		constant NUM_HCTR_BITS : natural := 11;    -- ceil(log2(HPIX_TOTAL));
		constant NUM_VCTR_BITS : natural := 10;    -- ceil(log2(VPIX_TOTAL));

		-- start address of the display buffer in memory
		constant MEM_START_ADDR : natural := 0;
		-- memory address length
		constant NUM_PIXADDR_BITS : natural := 20  -- ceil(log2(HPIX_VISIBLE*VPIX_VISIBLE))
	);

	port(
		-- pixel clock, reset
		-- pixel clock frequency = HPIX_TOTAL * VPIX_TOTAL * 60 Hz
		in_clk, in_rst : in std_logic;

		-- show test pattern?
		in_testpattern : in std_logic;

		-- video interface
		out_hpix, out_hpix_raw : out std_logic_vector(NUM_HCTR_BITS - 1 downto 0);
		out_vpix, out_vpix_raw : out std_logic_vector(NUM_VCTR_BITS - 1 downto 0);
		out_hsync, out_vsync, out_pixel_enable : out std_logic;
		out_pixel : out std_logic_vector(NUM_PIXEL_BITS - 1 downto 0);

		-- memory interface
		out_mem_addr : out std_logic_vector(NUM_PIXADDR_BITS - 1 downto 0);
		in_mem : in std_logic_vector(NUM_PIXEL_BITS - 1 downto 0)
	);
end entity;



architecture video_impl of video is
	-- current pixel counter in total range
	signal h_ctr, h_ctr_next : natural range 0 to HPIX_TOTAL - 1 := 0;
	signal v_ctr, v_ctr_next : natural range 0 to VPIX_TOTAL - 1 := 0;

	-- current pixel counter in visible range
	signal hpix : natural range 0 to HPIX_VISIBLE - 1 := 0;
	signal vpix : natural range 0 to VPIX_VISIBLE - 1 := 0;

	-- in visible range?
	signal visible_range : std_logic := '0';

	-- test pattern values
	signal pattern : std_logic_vector(NUM_PIXEL_BITS - 1 downto 0) := (others => '0');
begin

	-- row / column counters
	hvctr_proc : process(in_clk, in_rst) begin
		if in_rst = '1' then
			h_ctr <= 0;
			v_ctr <= 0;

		elsif rising_edge(in_clk) then
			h_ctr <= h_ctr_next;

			-- h_ctr is still at its previous value
			if h_ctr = HPIX_TOTAL - 1 then
				v_ctr <= v_ctr_next;
			end if;
		end if;
	end process;


	-- next column / row
	h_ctr_next <= 0 when h_ctr = HPIX_TOTAL - 1 else h_ctr + 1;
	v_ctr_next <= 0 when v_ctr = VPIX_TOTAL - 1 else v_ctr + 1;


	-- generate test pattern
	pixel_testpattern : process(visible_range, vpix, hpix) begin
		-- default value
		pattern <= (others => '0');

		-- output test pattern for debugging
		if visible_range = '1' then
			if vpix < VPIX_VISIBLE/2 and hpix < HPIX_VISIBLE/3 then
				pattern(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
					<= (others => '1');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
					<= (others => '0');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
					<= (others => '0');
			elsif vpix >= VPIX_VISIBLE/2 and vpix < VPIX_VISIBLE and hpix < HPIX_VISIBLE/3 then
				pattern(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
					<= (others => '0');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
					<= (others => '1');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
					<= (others => '0');
			elsif vpix < VPIX_VISIBLE/2 and hpix >= HPIX_VISIBLE/3 and hpix < 2*HPIX_VISIBLE/3 then
				pattern(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
					<= (others => '0');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
					<= (others => '0');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
					<= (others => '1');
			elsif vpix >= VPIX_VISIBLE/2 and vpix < VPIX_VISIBLE and hpix >= HPIX_VISIBLE/3 and hpix < 2*HPIX_VISIBLE/3 then
				pattern(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
					<= (others => '1');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
					<= (others => '1');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
					<= (others => '0');
			elsif vpix < VPIX_VISIBLE/2 and hpix >= 2*HPIX_VISIBLE/3 and hpix < HPIX_VISIBLE then
				pattern(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
					<= (others => '0');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
					<= (others => '1');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
					<= (others => '1');
			elsif vpix >= VPIX_VISIBLE/2 and vpix < VPIX_VISIBLE and hpix >= 2*HPIX_VISIBLE/3 and hpix < HPIX_VISIBLE then
				pattern(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
					<= (others => '1');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
					<= (others => '0');
				pattern(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
					<= (others => '1');
			end if;
		end if;
	end process;


	-- current pixel counters
	hpix <= h_ctr - HSYNC_DELAY
		when visible_range = '1'
			and h_ctr - HSYNC_DELAY >= 0
			and h_ctr - HSYNC_DELAY < HPIX_VISIBLE
		else 0;
	vpix <= v_ctr - VSYNC_DELAY
		when visible_range = '1'
			and v_ctr - VSYNC_DELAY >= 0
			and v_ctr - VSYNC_DELAY < VPIX_VISIBLE
		else 0;

	-- pixel counter
	out_hpix <= nat_to_logvec(hpix, out_hpix'length);
	out_vpix <= nat_to_logvec(vpix, out_vpix'length);

	-- raw pixel counter
	out_hpix_raw <= nat_to_logvec(h_ctr, out_hpix_raw'length);
	out_vpix_raw <= nat_to_logvec(v_ctr, out_vpix_raw'length);

	-- synchronisation signals
	out_hsync <= '1' when h_ctr >= HSYNC_START and h_ctr < HSYNC_STOP else '0';
	out_vsync <= '1' when v_ctr >= VSYNC_START and v_ctr < VSYNC_STOP else '0';
	out_pixel_enable <= visible_range;

	-- pixel counters in visible range?
	visible_range <= '1' when
		h_ctr >= HSYNC_DELAY and h_ctr < HPIX_VISIBLE + HSYNC_DELAY and
		v_ctr >= VSYNC_DELAY and v_ctr < VPIX_VISIBLE + VSYNC_DELAY
		else '0';

	-- pixel
	out_pixel <= in_mem when in_testpattern = '0' else pattern;

	-- requested memory address
	out_mem_addr <= nat_to_logvec(vpix*HPIX_VISIBLE + hpix
		+ MEM_START_ADDR, NUM_PIXADDR_BITS)
		when visible_range = '1' and in_testpattern = '0'
		else (others => '0');

end architecture;
