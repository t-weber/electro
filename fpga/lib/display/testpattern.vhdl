--
-- video testpattern
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date jan-2021, mar-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;



entity testpattern is
	generic(
		-- colour channels
		-- number of bits in one colour channel
		constant COLOUR_BITS : natural := 8;
		-- number of bits in all colour channels
		constant PIXEL_BITS : natural := 3 * COLOUR_BITS;

		-- rows and columns
		constant HPIX : natural := 1280;
		constant VPIX : natural := 720;

		-- counter bits
		constant HCTR_BITS : natural := 11;  -- ceil(log2(HPIX));
		constant VCTR_BITS : natural := 10   -- ceil(log2(VPIX))
	);

	port(
		in_hpix : in std_logic_vector(HCTR_BITS - 1 downto 0);
		in_vpix : in std_logic_vector(VCTR_BITS - 1 downto 0);

		out_pattern : out std_logic_vector(PIXEL_BITS - 1 downto 0)
	);
end entity;



architecture testpattern_impl of testpattern is
begin

	-- generate test pattern
	pixel_testpattern : process(in_vpix, in_hpix) begin
		-- default value
		out_pattern <= (others => '0');

		-- output test pattern
		if to_int(in_vpix) < VPIX/2 and to_int(in_hpix) < HPIX/3 then
			out_pattern(PIXEL_BITS - 1 downto PIXEL_BITS - COLOUR_BITS)
				<= (others => '1');
			out_pattern(PIXEL_BITS - COLOUR_BITS - 1 downto PIXEL_BITS - COLOUR_BITS*2)
				<= (others => '0');
			out_pattern(PIXEL_BITS - COLOUR_BITS*2 - 1 downto 0)
				<= (others => '0');
		elsif to_int(in_vpix) >= VPIX/2 and to_int(in_vpix) < VPIX and to_int(in_hpix) < HPIX/3 then
			out_pattern(PIXEL_BITS - 1 downto PIXEL_BITS - COLOUR_BITS)
				<= (others => '0');
			out_pattern(PIXEL_BITS - COLOUR_BITS - 1 downto PIXEL_BITS - COLOUR_BITS*2)
				<= (others => '1');
			out_pattern(PIXEL_BITS - COLOUR_BITS*2 - 1 downto 0)
				<= (others => '0');
		elsif to_int(in_vpix) < VPIX/2 and to_int(in_hpix) >= HPIX/3 and to_int(in_hpix) < 2*HPIX/3 then
			out_pattern(PIXEL_BITS - 1 downto PIXEL_BITS - COLOUR_BITS)
				<= (others => '0');
			out_pattern(PIXEL_BITS - COLOUR_BITS - 1 downto PIXEL_BITS - COLOUR_BITS*2)
				<= (others => '0');
			out_pattern(PIXEL_BITS - COLOUR_BITS*2 - 1 downto 0)
				<= (others => '1');
		elsif to_int(in_vpix) >= VPIX/2 and to_int(in_vpix) < VPIX and to_int(in_hpix) >= HPIX/3 and to_int(in_hpix) < 2*HPIX/3 then
			out_pattern(PIXEL_BITS - 1 downto PIXEL_BITS - COLOUR_BITS)
				<= (others => '1');
			out_pattern(PIXEL_BITS - COLOUR_BITS - 1 downto PIXEL_BITS - COLOUR_BITS*2)
				<= (others => '1');
			out_pattern(PIXEL_BITS - COLOUR_BITS*2 - 1 downto 0)
				<= (others => '0');
		elsif to_int(in_vpix) < VPIX/2 and to_int(in_hpix) >= 2*HPIX/3 and to_int(in_hpix) < HPIX then
			out_pattern(PIXEL_BITS - 1 downto PIXEL_BITS - COLOUR_BITS)
				<= (others => '0');
			out_pattern(PIXEL_BITS - COLOUR_BITS - 1 downto PIXEL_BITS - COLOUR_BITS*2)
				<= (others => '1');
			out_pattern(PIXEL_BITS - COLOUR_BITS*2 - 1 downto 0)
				<= (others => '1');
		elsif to_int(in_vpix) >= VPIX/2 and to_int(in_vpix) < VPIX and to_int(in_hpix) >= 2*HPIX/3 and to_int(in_hpix) < HPIX then
			out_pattern(PIXEL_BITS - 1 downto PIXEL_BITS - COLOUR_BITS)
				<= (others => '1');
			out_pattern(PIXEL_BITS - COLOUR_BITS - 1 downto PIXEL_BITS - COLOUR_BITS*2)
				<= (others => '0');
			out_pattern(PIXEL_BITS - COLOUR_BITS*2 - 1 downto 0)
				<= (others => '1');
		end if;
	end process;

end architecture;
