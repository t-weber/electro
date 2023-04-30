--
-- seven segment leds
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date oct-2020
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;



--
-- pin declaration
--
entity sevenseg is
	generic
	(
		ZERO_IS_ON : in std_logic := '0';
		INVERSE_NUMBERING : in std_logic := '0'
	);

	port
	(
		in_digit : in std_logic_vector(3 downto 0);
		out_leds : out std_logic_vector(6 downto 0)
	);
end entity;



--
-- implementation
--
architecture sevenseg_impl of sevenseg is

	type t_ledvec is array(0 to 1, 0 to 15) of std_logic_vector(7 downto 0);

	-- INVERSE_NUMBERING as integer
	constant inv_numb : integer := log_to_int(INVERSE_NUMBERING);

	-- constants, see: https://en.wikipedia.org/wiki/Seven-segment_display
	constant ledvec : t_ledvec := 
	(
		-- non-inverted numbering
		(
			x"7e", x"30", x"6d", x"79", -- 0-3
			x"33", x"5b", x"5f", x"70", -- 4-7
			x"7f", x"7b", x"77", x"1f", -- 8-b
			x"4e", x"3d", x"4f", x"47"  -- c-f
		),

		-- inverted numbering
		(
			x"3f", x"06", x"5b", x"4f", -- 0-3
			x"66", x"6d", x"7d", x"07", -- 4-7
			x"7f", x"6f", x"77", x"7c", -- 8-b
			x"39", x"5e", x"79", x"71"  -- c-f
		)
	);

	signal leds : std_logic_vector(6 downto 0);
begin
	leds <= ledvec(inv_numb,  to_int(in_digit))(6 downto 0);

	--with ZERO_IS_ON select out_leds <=
	--	not leds(6 downto 0) when '1',
	--	leds(6 downto 0) when others;

	gen_leds_zero_on : if ZERO_IS_ON='1' generate
		out_leds <= not leds;
	end generate;

	gen_leds_zero_off : if ZERO_IS_ON='0' generate
		out_leds <= leds;
	end generate;
end architecture;
