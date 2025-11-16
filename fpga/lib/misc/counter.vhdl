--
-- counter
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 13 march 2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity counter is
	generic
	(
		constant BITS : natural := 8
	);

	port
	(
		in_clk, in_reset : in std_logic;
		--in_enable : in std_logic;

		-- counter value
		out_counter : out std_logic_vector(BITS-1 downto 0);

		-- wire for beginning and end of count sequence
		out_at_start, out_at_end : out std_logic
	);
end entity;



architecture counter_impl of counter is
	signal counter : std_logic_vector(BITS-1 downto 0) := (others => '0');

	constant max_val : std_logic_vector(BITS-1 downto 0) := (others => '1');
	constant min_val : std_logic_vector(BITS-1 downto 0) := (others => '0');

begin

	out_at_start <= '1' when counter = min_val else '0';
	out_at_end   <= '1' when counter = max_val else '0';

	out_counter <= counter; --when in_enable = '1' else (others => 'Z');


	proc_ctr : process(in_clk, in_reset) is
	begin
		if in_reset = '1' then
			-- asynchronously reset counter
			counter <= (others => '0');
		elsif rising_edge(in_clk) then
			--if in_reset = '1' then
			--	-- synchronously reset counter
			--	counter <= (others => '0');
			--else
				-- advance counter
				counter <= inc_logvec(counter, 1);
			--end if;
		end if;
	end process;

end architecture;
