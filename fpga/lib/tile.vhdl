--
-- get a tile number from a pixel number (e.g. for text display)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date apr-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



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
		constant NUM_TILES_Y : natural := SCREEN_HEIGHT / TILE_HEIGHT;

		-- address widths
		constant SCREEN_WIDTH_BITS : natural := 11;  -- ceil(log2(SCREEN_WIDTH));
		constant SCREEN_HEIGHT_BITS : natural := 10; -- ceil(log2(SCREEN_HEIGHT));

		constant TILE_WIDTH_BITS : natural := 4;     -- ceil(log2(TILE_WIDTH));
		constant TILE_HEIGHT_BITS : natural := 5;    -- ceil(log2(TILE_HEIGHT));

		constant TILE_NUM_X_BITS : natural := 7;     -- ceil(log2(NUM_TILES_X));
		constant TILE_NUM_Y_BITS : natural := 5;     -- ceil(log2(NUM_TILES_Y));
		constant TILE_NUM_BITS : natural := 12       -- ceil(log2(NUM_TILES_X * NUM_TILES_Y));
	);

	port(
		in_x : in std_logic_vector(SCREEN_WIDTH_BITS-1 downto 0);
		in_y : in std_logic_vector(SCREEN_HEIGHT_BITS-1 downto 0);

		-- tile number
		out_tile_x : out std_logic_vector(TILE_NUM_X_BITS-1 downto 0);
		out_tile_y : out std_logic_vector(TILE_NUM_Y_BITS-1 downto 0);
		out_tile_num : out std_logic_vector(TILE_NUM_BITS-1 downto 0);

		-- pixel number in tile
		out_tile_pix_x : out std_logic_vector(TILE_WIDTH_BITS-1 downto 0);
		out_tile_pix_y : out std_logic_vector(TILE_HEIGHT_BITS-1 downto 0)
	);
end entity;



architecture tile_impl of tile is
	signal tile_x : natural range 0 to TILE_WIDTH - 1 := 0;
	signal tile_y : natural range 0 to TILE_HEIGHT - 1 := 0;

begin

	tile_x <= to_int(in_x) / TILE_WIDTH;
	tile_y <= to_int(in_y) / TILE_HEIGHT;

	out_tile_x <= int_to_logvec(tile_x, TILE_NUM_X_BITS);
	out_tile_y <= int_to_logvec(tile_y, TILE_NUM_Y_BITS);
	out_tile_num <= int_to_logvec(tile_y * NUM_TILES_X + tile_x, TILE_NUM_BITS);

	out_tile_pix_x <= int_to_logvec(to_int(in_x) mod TILE_WIDTH, TILE_WIDTH_BITS);
	out_tile_pix_y <= int_to_logvec(to_int(in_y) mod TILE_HEIGHT, TILE_HEIGHT_BITS);

end architecture;
