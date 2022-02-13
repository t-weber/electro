--
-- simple counter
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date February-2022
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;



--
-- interface
--
entity counter is
	generic
	(
		-- number of bits for counter
		constant num_ctrbits : natural := 16
	);

	port(
		in_clk, in_rst : in std_logic;
		out_ctr : out std_logic_vector(num_ctrbits-1 downto 0)
	);
end entity;



--
-- implementation
--
architecture counter_impl of counter is
	signal ctr, next_ctr : std_logic_vector(num_ctrbits-1 downto 0) := (others=>'0');
begin

	ctrprc : process(in_clk, in_rst) begin
		if in_rst='1' then
			ctr <= (others => '0');
		elsif rising_edge(in_clk) then
			ctr <= next_ctr;
		end if;
	end process;

	next_ctr <= inc_logvec(ctr, 1);
	out_ctr <= ctr;
end architecture;
