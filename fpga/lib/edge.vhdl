--
-- get edge of a signal
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date jan-2021
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;


entity edge is
	generic(
		-- number of steps to sample in shift register
		constant NUM_STEPS : natural := 4;

		-- get positive or negative edge?
		constant POS_EDGE : std_logic := '1'
	);

	port(
		-- clock
		in_clk : in std_logic;

		-- signal to get edge from
		in_signal : in std_logic;

		-- edge of that signal
		out_edge : out std_logic
	);
end entity;


architecture edge_impl of edge is
	signal shiftreg : std_logic_vector(0 to NUM_STEPS-1);
begin

	-- output edge
	gen_posedge : if POS_EDGE='1' generate
		out_edge <= shiftreg(NUM_STEPS-2) and (not shiftreg(NUM_STEPS-1));
	else generate
		out_edge <= (not shiftreg(NUM_STEPS-2)) and shiftreg(NUM_STEPS-1);
	end generate;


	-- synchronise to clock
	sync_proc : process(in_clk)
	begin
		if rising_edge(in_clk) then
			shiftreg(0) <= in_signal;

			shiftloop: for i in 1 to NUM_STEPS-1 loop
				shiftreg(i) <= shiftreg(i-1);
			end loop;
		end if;
	end process;

end architecture;
