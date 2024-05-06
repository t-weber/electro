--
-- video synchronisation signal test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 28 March 2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  &&  ghdl -a --std=08 ../display/testpattern.vhdl  &&  ghdl -a --std=08 ../display/video.vhdl  &&  ghdl -a --std=08 video_tb.vhdl  &&  ghdl -e --std=08 video_tb video_tb_arch
-- ghdl -r --std=08 video_tb video_tb_arch --vcd=video_tb.vcd --stop-time=3000ns
-- gtkwave video_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity video_tb is
end entity;


architecture video_tb_arch of video_tb is
	-- clock
	constant CLK_DELAY : time := 20 ns;
	signal clk, rst : std_logic := '0';

	signal hsync, vsync, pixel_enable : std_logic := '0';
	signal hpix, hpix_raw : std_logic_vector(3 downto 0) := (others => '0');
	signal vpix, vpix_raw : std_logic_vector(3 downto 0) := (others => '0');

	signal pixel : std_logic_vector(23 downto 0) := (others => '0');

begin
	-- generate clock
	clk <= not clk after CLK_DELAY;


	-- instantiate video module
	video_ent : entity work.video
		generic map(HCTR_BITS => 4, VCTR_BITS => 4,

			HPIX_VISIBLE => 4, -- HPIX_TOTAL => 5,
			HSYNC_START => 0, HSYNC_STOP => 1, HSYNC_DELAY => 2,

			VPIX_VISIBLE => 4, -- VPIX_TOTAL => 5,
			VSYNC_START => 0, VSYNC_STOP => 2, VSYNC_DELAY => 2)

		port map(in_clk => clk, in_rst => rst,
			in_testpattern => '1',
			in_mem => (others => '0'),

			out_hsync => hsync, out_vsync => vsync,
			out_pixel_enable => pixel_enable,
			out_hpix => hpix, out_vpix => vpix,
			out_hpix_raw => hpix_raw, out_vpix_raw => vpix_raw,
			out_pixel => pixel);


	sim_report : process(clk)
	begin
		report lf
		      & "clk = "   & std_logic'image(clk)
		      & ", hsync = " & std_logic'image(hsync)
		      & ", vsync = " & std_logic'image(vsync)
		      & ", enable = " & std_logic'image(pixel_enable)
		      & ", x = " & integer'image(to_int(hpix))
		      & ", y = " & integer'image(to_int(vpix))
		      & ", xr = " & integer'image(to_int(hpix_raw))
		      & ", yr = " & integer'image(to_int(vpix_raw))
		      & ", pixel = " & to_hstring(pixel);
	end process;

end architecture;
