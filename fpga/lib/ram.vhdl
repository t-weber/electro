--
-- ram
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 20-feb-2024
-- @license see 'LICENSE' file
--
-- References:
--     Listing 5.24 on pp. 119-120 of the book by Pong P. Chu, 2011, ISBN 978-1-118-00888-1.
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity ram is
	generic(
		constant NUM_PORTS : natural := 2;
		constant ADDR_BITS : natural := 3;
		constant WORD_BITS : natural := 8;
		constant NUM_WORDS : natural := 2**ADDR_BITS
	);

	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- enable signals
		in_read_ena, in_write_ena : in t_logicarray(0 to NUM_PORTS-1);

		-- address and data
		in_addr  : in  t_logicvecarray(0 to NUM_PORTS-1)(ADDR_BITS-1 downto 0);
		in_data  : in  t_logicvecarray(0 to NUM_PORTS-1)(WORD_BITS-1 downto 0);
		out_data : out t_logicvecarray(0 to NUM_PORTS-1)(WORD_BITS-1 downto 0)
	);
end entity;



architecture ram_impl of ram is
	subtype t_word is std_logic_vector(WORD_BITS-1 downto 0);
	type t_words is array(0 to NUM_WORDS-1) of t_word;

	-- memory flip-flops
	signal words : t_words; --:= (x"31", x"32", x"33", x"34", x"35", x"36", x"37", x"38");

begin

	gen_ports : for portidx in 0 to NUM_PORTS-1 generate
	begin
		process(in_clk, in_rst)
		begin
			if in_rst = '1' then
				-- fill ram with zeros
				for i in 0 to NUM_WORDS-1 loop
					words(i) <= (others => '0');
				end loop;

			elsif rising_edge(in_clk) then
				-- write data to ram: will be written in the next cycle
				if in_write_ena(portidx) = '1' then
					words(to_int(in_addr(portidx))) <= in_data(portidx);
				end if;

				-- read data from ram: will be available in the next cycle
				if in_read_ena(portidx) = '1' then
					out_data(portidx) <= words(to_int(in_addr(portidx)));
				else
					out_data(portidx) <= (others => 'Z');
				end if;
			end if;
		end process;
	end generate;

end architecture;
