--
-- ram (should be recognised as block ram by synthesiser)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 20-feb-2024
-- @license see 'LICENSE' file
--
-- References:
--     - Listing 5.24 on pp. 119-120 of the book by Pong P. Chu, 2011, ISBN 978-1-118-00888-1.
--     - Chapter 7 in: https://docs.xilinx.com/v/u/en-US/xst_v6s6
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
		in_read_ena, in_write_ena : in t_logicarray(0 to NUM_PORTS - 1);

		-- address and data
		in_addr  : in  t_logicvecarray(0 to NUM_PORTS - 1)(ADDR_BITS - 1 downto 0);
		in_data  : in  t_logicvecarray(0 to NUM_PORTS - 1)(WORD_BITS - 1 downto 0);
		out_data : out t_logicvecarray(0 to NUM_PORTS - 1)(WORD_BITS - 1 downto 0)
	);
end entity;



architecture ram_impl of ram is
	subtype t_word is std_logic_vector(WORD_BITS - 1 downto 0);
	type t_words is array(0 to NUM_WORDS - 1) of t_word;

	-- memory flip-flops (should be recognised as multi-port syncram)
	signal words : t_words := (others => (others => '0'));

begin

	gen_ports : for portidx in 0 to NUM_PORTS - 1 generate
	-- repeat this process for each port if generate for loops don't work
	-- or if the module is not recognised as block ram
	--gen_port0 : if NUM_PORTS >= 1 generate
	--	constant portidx : natural := 0;

	-- optional output register
	--signal outreg : std_logic_vector(WORD_BITS - 1 downto 0);

	begin
		--out_data(portidx) <= outreg;

		process(in_clk, in_rst)
		begin
			if in_rst = '1' then
				-- fill ram with zeros
				words <= (others => (others => '0'));
				--outreg <= (others => '0');

			elsif rising_edge(in_clk) then
				-- write data to ram: will be written in the next cycle
				-- if NUM_WORDS == 2**ADDR_BITS the range check against NUM_WORDS is not needed
				if in_write_ena(portidx) = '1' and to_int(in_addr(portidx)) < NUM_WORDS then
					words(to_int(in_addr(portidx))) <= in_data(portidx);
				end if;

				-- read data from ram: will be available in the next cycle
				-- if NUM_WORDS == 2**ADDR_BITS the range check against NUM_WORDS is not needed
				if in_read_ena(portidx) = '1' and to_int(in_addr(portidx)) < NUM_WORDS then
					--outreg <= words(to_int(in_addr(portidx)));
					out_data(portidx) <= words(to_int(in_addr(portidx)));
				--else
				--	out_data(portidx) <= (others => '0');
				end if;
			end if;
		end process;
	end generate;  -- gen_ports
end architecture;
