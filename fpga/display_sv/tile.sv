/**
 * get a tile number from a pixel number (e.g. for text display)
 * @author Tobias Weber <tobias.weber@tum.de>
 * @date 5-may-2024
 * @license see 'LICENSE' file
 */

module tile
	#(
		// screen resolution
		parameter SCREEN_WIDTH = 1280,
		parameter SCREEN_HEIGHT = 720,

		// tile resolution
		parameter TILE_WIDTH = 16,
		parameter TILE_HEIGHT = 24,

		// number of tiles
		parameter TILES_X = SCREEN_WIDTH / TILE_WIDTH,
		parameter TILES_Y = SCREEN_HEIGHT / TILE_HEIGHT,

		// address widths
		parameter SCREEN_WIDTH_BITS = $clog2(SCREEN_WIDTH),
		parameter SCREEN_HEIGHT_BITS = $clog2(SCREEN_HEIGHT),

		parameter TILE_WIDTH_BITS = $clog2(TILE_WIDTH),
		parameter TILE_HEIGHT_BITS = $clog2(TILE_HEIGHT),

		parameter TILE_X_BITS   = $clog2(TILES_X),
		parameter TILE_Y_BITS   = $clog2(TILES_Y),
		parameter TILE_NUM_BITS = $clog2(TILES_X * TILES_Y)
	 )
	(
		input wire [SCREEN_WIDTH_BITS-1 : 0] in_x,
		input wire [SCREEN_HEIGHT_BITS-1 : 0] in_y,

		// tile number
		output wire [TILE_X_BITS-1 : 0] out_tile_x,
		output wire [TILE_Y_BITS-1 : 0] out_tile_y,
		output wire [TILE_NUM_BITS-1 : 0] out_tile_num,

		// pixel number in tile
		output wire [TILE_WIDTH_BITS-1 : 0] out_tile_pix_x,
		output wire [TILE_HEIGHT_BITS-1 : 0] out_tile_pix_y
	);


logic [TILE_X_BITS : 0] tile_x = in_x / TILE_WIDTH;
logic [TILE_Y_BITS : 0] tile_y = in_y / TILE_HEIGHT;

assign out_tile_x = tile_x;
assign out_tile_y = tile_y;
assign out_tile_num = tile_y * TILES_X + tile_x;

assign out_tile_pix_x = in_x % TILE_WIDTH;
assign out_tile_pix_y = in_y % TILE_HEIGHT;


endmodule
