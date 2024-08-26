--
-- clock domain synchronisation
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

		-- buffer address length to pass the data to the slow clock domain
		constant FIFO_ADDR_BITS : natural := 8;

		-- word length
		constant BITS : natural := 8
	);

	port(
		-- reset
		signal in_rst : in std_logic;

		-- clocks
		signal in_clk_fast, in_clk_slow : in std_logic;

		-- data generated in slow clock domain
		signal in_data : in std_logic_vector(BITS-1 downto 0);

		-- stable data in fast clock domain
		signal out_data : out std_logic_vector(BITS-1 downto 0)
	);
end entity;



--
-- clock domain synchronisation (passing from slow to fast clock)
--
architecture clksync_tofast of clksync is
	-- flip-flops to pass the data to the fast clock domain
	signal data_stable : t_logicvecarray(0 to FLIPFLOPS-1)(BITS-1 downto 0);

begin
	process(in_clk_fast)
	begin
		if rising_edge(in_clk_fast) then
			if in_rst = '1' then
				data_stable <= (others => (others => '0'));
			else
				-- move data through flip-flop chain
				data_stable(0) <= in_data;

				for i in 1 to FLIPFLOPS - 1 loop
					data_stable(i) <= data_stable(i-1);
				end loop;
			end if;
		end if;
	end process;


	-- output synchronised data
	out_data <= data_stable(FLIPFLOPS - 1);

end architecture;



--
-- clock domain synchronisation (passing from fast to slow clock)
--
architecture clksync_toslow of clksync is
begin

	-- fifo buffer
	mod_fifo : entity work.fifo(fifo_direct)
		generic map(ADDR_BITS => FIFO_ADDR_BITS, WORD_BITS => BITS)
		port map(
			in_rst => in_rst,
			in_clk_insert => in_clk_fast, in_clk_remove => in_clk_slow,
			in_data => in_data, out_back => out_data,
			in_insert => '1', in_remove => '1',
			out_ready_to_insert => open,
			out_ready_to_remove => open,
			out_empty => open
		);

end architecture;
