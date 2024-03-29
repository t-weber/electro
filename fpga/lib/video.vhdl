--
-- video
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date jan-2021, mar-2024
-- @license see 'LICENSE' file
--
-- References:
--	https://www.digikey.com/eewiki/pages/viewpage.action?pageId=15925278
--	https://academic.csuohio.edu/chu_p/rtl/sopc_vhdl.html
--	https://www.analog.com/media/en/technical-documentation/user-guides/ADV7513_Programming_Guide.pdf
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;



entity video is
	generic(
		-- memory address length
		constant NUM_PIXADDR_BITS : natural := 19;

		-- colour channels
		-- number of bits in one colour channel
		constant NUM_COLOUR_BITS : natural := 8;
		-- number of bits in all colour channels
		constant NUM_PIXEL_BITS : natural := 3 * NUM_COLOUR_BITS;

		-- rows
		constant HPIX_VISIBLE : natural := 1920;
		constant HPIX_TOTAL   : natural := 2200;
		constant HSYNC_START  : natural := 0;
		constant HSYNC_STOP   : natural := 44;
		constant HSYNC_DELAY  : natural := 191;

		-- columns
		constant VPIX_VISIBLE : natural := 1080;
		constant VPIX_TOTAL   : natural := 1125;
		constant VSYNC_START  : natural := 0;
		constant VSYNC_STOP   : natural := 5;
		constant VSYNC_DELAY  : natural := 41;

		-- counter bits
		constant NUM_HCTR_BITS : natural := 13; -- ceil(log2(HPIX_TOTAL)) + 1;
		constant NUM_VCTR_BITS : natural := 12; -- ceil(log2(VPIX_TOTAL)) + 1;

		-- start address of the display buffer in memory
		constant MEM_START_ADDR : natural := 0
	);

	port(
		-- clock, reset
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
	signal h_ctr_fin : std_logic := '0';

	-- current pixel counter in visible range
	signal hpix : natural range 0 to HPIX_VISIBLE := 0;
	signal vpix : natural range 0 to VPIX_VISIBLE := 0;

	-- in visible range?
	signal output_pixel : std_logic := '0';
begin

	-- row
	hctr_proc : process(in_clk, in_rst) begin
		if in_rst = '1' then
			h_ctr <= 0;
		elsif rising_edge(in_clk) then
			h_ctr <= h_ctr_next;
		end if;
	end process;


	-- column
	vctr_proc : process(h_ctr_fin, in_rst) begin
		if in_rst = '1' then
			v_ctr <= 0;
		elsif rising_edge(h_ctr_fin) then
			v_ctr <= v_ctr_next;
		end if;
	end process;


	-- next column / row
	h_ctr_next <= 0 when h_ctr = HPIX_TOTAL - 1 else h_ctr + 1;
	v_ctr_next <= 0 when v_ctr = VPIX_TOTAL - 1 else v_ctr + 1;


	-- column finished
	h_ctr_fin <= '1' when h_ctr = HPIX_TOTAL - 1 else '0';


	-- pixel output
	pixel_proc : process(in_clk, in_rst) begin

		if in_rst = '1' then
			-- reset
			out_pixel <= (others => '0');

		elsif rising_edge(in_clk) then
			if output_pixel = '1' then
				-- inside visible pixel range

				if in_testpattern = '1' then
					-- output test pattern for debugging
					if vpix < VPIX_VISIBLE/2 and hpix < HPIX_VISIBLE/3 then
						out_pixel(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
							<= (others => '1');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
							<= (others => '0');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
							<= (others => '0');
					elsif vpix >= VPIX_VISIBLE/2 and vpix < VPIX_VISIBLE and hpix < HPIX_VISIBLE/3 then
						out_pixel(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
							<= (others => '0');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
							<= (others => '1');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
							<= (others => '0');
					elsif vpix < VPIX_VISIBLE/2 and hpix >= HPIX_VISIBLE/3 and hpix < 2*HPIX_VISIBLE/3 then
						out_pixel(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
							<= (others => '0');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
							<= (others => '0');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
							<= (others => '1');
					elsif vpix >= VPIX_VISIBLE/2 and vpix < VPIX_VISIBLE and hpix >= HPIX_VISIBLE/3 and hpix < 2*HPIX_VISIBLE/3 then
						out_pixel(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
							<= (others => '1');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
							<= (others => '1');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
							<= (others => '0');
					elsif vpix < VPIX_VISIBLE/2 and hpix >= 2*HPIX_VISIBLE/3 and hpix < HPIX_VISIBLE then
						out_pixel(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
							<= (others => '0');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
							<= (others => '1');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
							<= (others => '1');
					elsif vpix >= VPIX_VISIBLE/2 and vpix < VPIX_VISIBLE and hpix >= 2*HPIX_VISIBLE/3 and hpix < HPIX_VISIBLE then
						out_pixel(NUM_PIXEL_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS)
							<= (others => '1');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS - 1 downto NUM_PIXEL_BITS - NUM_COLOUR_BITS*2)
							<= (others => '0');
						out_pixel(NUM_PIXEL_BITS - NUM_COLOUR_BITS*2 - 1 downto 0)
							<= (others => '1');
					else
						out_pixel <= (others => '0');
					end if;

				else
					-- output video memory
					out_mem_addr <=
						nat_to_logvec(vpix*HPIX_VISIBLE + hpix + MEM_START_ADDR,
							NUM_PIXADDR_BITS);
					out_pixel <= in_mem;
				end if;

			else
				-- outside visible pixel range
				out_pixel <= (others => '0');
			end if;
		end if;
	end process;


	-- current pixel counters
	hpix <= h_ctr - HSYNC_DELAY - 1 when output_pixel = '1' else 0;
	vpix <= v_ctr - VSYNC_DELAY - 1 when output_pixel = '1' else 0;

	out_hpix <= nat_to_logvec(hpix, out_hpix'length);
	out_vpix <= nat_to_logvec(vpix, out_vpix'length);

	out_hpix_raw <= nat_to_logvec(h_ctr, out_hpix_raw'length);
	out_vpix_raw <= nat_to_logvec(v_ctr, out_vpix_raw'length);


	-- synchronisation signals
	out_hsync <= '1' when h_ctr >= HSYNC_START and h_ctr < HSYNC_STOP else '0';
	out_vsync <= '1' when v_ctr >= VSYNC_START and v_ctr < VSYNC_STOP else '0';
	out_pixel_enable <= output_pixel;

	output_pixel <= '1' when
		h_ctr > HSYNC_DELAY and h_ctr <= HPIX_VISIBLE + HSYNC_DELAY and
		v_ctr > VSYNC_DELAY and v_ctr <= VPIX_VISIBLE + VSYNC_DELAY
		else '0';

end architecture;
