--
-- clock domain synchronisation (passing from slow to fast clock)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 17-mar-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity clksync is
	generic(
		-- flip-flops to pass the data to the fast clock domain
		constant FLIPFLOPS : natural := 2;

		-- word length
		constant BITS : natural := 8
	);

	port(
		-- fast clock and reset
		signal in_clk, in_rst : in std_logic;

		-- data generated in slow clock domain
		signal in_data : in std_logic_vector(BITS-1 downto 0);

		-- stable data in fast clock domain
		signal out_data : out std_logic_vector(BITS-1 downto 0)
	);
end entity;


architecture clksync_impl of clksync is
	-- flip-flops to pass the data to the fast clock domain
	signal data_stable : t_logicvecarray(0 to FLIPFLOPS-1)(BITS-1 downto 0);

begin
	process(in_clk, in_rst)
	begin
		if in_rst = '1' then
			data_stable <= (others => (others => '0'));

		elsif rising_edge(in_clk) then
			-- move data through flip-flop chain
			data_stable(0) <= in_data;

			for i in 1 to FLIPFLOPS - 1 loop
				data_stable(i) <= data_stable(i-1);
			end loop;
		end if;
	end process;


	-- output synchronised data
	out_data <= data_stable(FLIPFLOPS - 1);

end architecture;
