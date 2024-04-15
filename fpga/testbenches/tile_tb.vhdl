--
-- tile number testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date apr-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  &&  ghdl -a --std=08 ../lib/tile.vhdl  &&  ghdl -a --std=08 tile_tb.vhdl  &&  ghdl -e --std=08 tile_tb tile_tb_arch
-- ghdl -r --std=08 tile_tb tile_tb_arch --vcd=tile_tb.vcd --stop-time=3000ns
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity tile_tb is
end entity;


architecture tile_tb_arch of tile_tb is
	signal tile_x, tile_y, tile_num : natural;
	signal tile_pix_x, tile_pix_y : natural;

begin

	-- instantiate tile module
	tile_ent : entity work.tile
		generic map(
			SCREEN_WIDTH => 200, SCREEN_HEIGHT => 100,
			TILE_WIDTH => 20, TILE_HEIGHT => 10
		)
		port map(
			in_x => 25, in_y => 25,
			out_tile_x => tile_x, out_tile_y => tile_y, out_tile_num => tile_num,
			out_tile_pix_x => tile_pix_x, out_tile_pix_y => tile_pix_y
		);


	sim_report : process(all)
	begin
		report lf
		      & "tile x = "   & natural'image(tile_x)
		      & ", tile y = " & natural'image(tile_y)
		      & ", tile number = " & natural'image(tile_num)
		      & ", tile pixel x = " & natural'image(tile_pix_x)
		      & ", tile pixel y = " & natural'image(tile_pix_y);
	end process;

end architecture;
