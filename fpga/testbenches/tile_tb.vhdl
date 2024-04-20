--
-- tile number testbench
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date apr-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/conv.vhdl  &&  ghdl -a --std=08 ../video/tile.vhdl  &&  ghdl -a --std=08 tile_tb.vhdl  &&  ghdl -e --std=08 tile_tb tile_tb_arch
-- ghdl -r --std=08 tile_tb tile_tb_arch --vcd=tile_tb.vcd --stop-time=3000ns
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity tile_tb is
end entity;


architecture tile_tb_arch of tile_tb is
	signal tile_x : std_logic_vector(6 downto 0) := (others => '0');
	signal tile_y : std_logic_vector(4 downto 0) := (others => '0');
	signal tile_num : std_logic_vector(11 downto 0) := (others => '0');
	signal tile_pix_x : std_logic_vector(3 downto 0) := (others => '0');
	signal tile_pix_y : std_logic_vector(4 downto 0) := (others => '0');

begin

	-- instantiate tile module
	tile_ent : entity work.tile
		generic map(
			SCREEN_WIDTH => 200, SCREEN_HEIGHT => 100,
			TILE_WIDTH => 20, TILE_HEIGHT => 10
		)
		port map(
			in_x => int_to_logvec(25, 11), in_y => int_to_logvec(25, 10),
			out_tile_x => tile_x, out_tile_y => tile_y, out_tile_num => tile_num,
			out_tile_pix_x => tile_pix_x, out_tile_pix_y => tile_pix_y
		);


	sim_report : process(all)
	begin
		report lf
		      & "tile x = "   & integer'image(to_int(tile_x))
		      & ", tile y = " & integer'image(to_int(tile_y))
		      & ", tile number = " & integer'image(to_int(tile_num))
		      & ", tile pixel x = " & integer'image(to_int(tile_pix_x))
		      & ", tile pixel y = " & integer'image(to_int(tile_pix_y));
	end process;

end architecture;
