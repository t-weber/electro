--
-- ROM
-- @author Tobias Weber
-- @date 27-jan-2024
-- @license see 'LICENSE' file
--
-- ./genrom -l 20 -f 0 -t vhdl rom.txt
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity rom is
	generic(
		constant NUM_PORTS : natural := 2;
		constant ADDRBITS  : natural := 7;
		constant WORDBITS  : natural := 8;
		constant NUM_WORDS : natural := 80
	);

	port(
		in_addr  : in  t_logicvecarray(0 to NUM_PORTS-1)(ADDRBITS-1 downto 0);
		out_data : out t_logicvecarray(0 to NUM_PORTS-1)(WORDBITS-1 downto 0)
	);
end entity;


architecture rom_impl of rom is
	subtype t_word is std_logic_vector(WORDBITS-1 downto 0);
	type t_words is array(0 to NUM_WORDS-1) of t_word;

	constant words : t_words :=
	(
		x"4c", x"69", x"6e", x"65", x"20", x"31", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", 
		x"4c", x"69", x"6e", x"65", x"20", x"32", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", 
		x"4c", x"69", x"6e", x"65", x"20", x"33", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", 
		x"4c", x"69", x"6e", x"65", x"20", x"34", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20", x"20"
	);

begin
	gen_ports : for portidx in 0 to NUM_PORTS-1 generate
	begin
		out_data(portidx) <= words(to_int(in_addr(portidx)));
	end generate;

end architecture;
