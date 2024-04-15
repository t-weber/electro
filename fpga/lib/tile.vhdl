--
-- get a tile number from a pixel number (e.g. for text display)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date apr-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;



entity tile is
	generic(
		-- screen resolution
		constant SCREEN_WIDTH : natural := 1280;
		constant SCREEN_HEIGHT : natural := 720;

		-- tile resolution
		constant TILE_WIDTH : natural := 16;
		constant TILE_HEIGHT : natural := 24;

		-- number of tiles
		constant NUM_TILES_X : natural := SCREEN_WIDTH / TILE_WIDTH;
		constant NUM_TILES_Y : natural := SCREEN_HEIGHT / TILE_HEIGHT
	);

	port(
		in_x : in natural range 0 to SCREEN_WIDTH - 1;
		in_y : in natural range 0 to SCREEN_HEIGHT - 1;

		-- tile number
		out_tile_x : out natural range 0 to NUM_TILES_X - 1;
		out_tile_y : out natural range 0 to NUM_TILES_Y - 1;
		out_tile_num : out natural range 0 to TILE_WIDTH*TILE_HEIGHT - 1;

		-- pixel number in tile
		out_tile_pix_x : out natural range 0 to TILE_WIDTH - 1;
		out_tile_pix_y : out natural range 0 to TILE_HEIGHT - 1
	);
end entity;



architecture tile_impl of tile is
	signal tile_x : natural range 0 to TILE_WIDTH - 1 := 0;
	signal tile_y : natural range 0 to TILE_HEIGHT - 1 := 0;

begin

	tile_x <= in_x / TILE_WIDTH;
	tile_y <= in_y / TILE_HEIGHT;

	out_tile_x <= tile_x;
	out_tile_y <= tile_y;
	out_tile_num <= tile_y * NUM_TILES_X + tile_x;

	out_tile_pix_x <= in_x mod TILE_WIDTH;
	out_tile_pix_y <= in_y mod TILE_HEIGHT;

end architecture;
