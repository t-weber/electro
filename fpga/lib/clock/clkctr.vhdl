--
-- generates a clock via a counter
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date may-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;



entity clkctr is
	generic(
		-- counter to flip clock signal
		constant COUNTER : natural := 10;

		-- reset value of clock
		constant CLK_INIT : std_logic := '0';

		constant USE_RISING_EDGE : std_logic := '1'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- output clock
		out_clk : out std_logic
	);
end entity;



architecture clkctr_impl of clkctr is
	-- generated clock
	signal clk : std_logic := CLK_INIT;

begin
	-- output slower clock
	out_clk <= clk;


	--
	-- generate clock
	--
	ctrprc_gen_if : if USE_RISING_EDGE = '1' generate
		proc_clk : process(in_clk, in_reset)
			variable clk_ctr : natural range 0 to COUNTER - 1 := 0;
		begin
			-- asynchronous reset
			if in_reset = '1' then
				clk_ctr := 0;
				clk <= CLK_INIT;

			-- clock
			elsif rising_edge(in_clk) then
				if clk_ctr = COUNTER - 1 then
					clk <= not clk;
					clk_ctr := 0;
				else
					clk_ctr := clk_ctr + 1;
				end if;
			end if;
		end process;
	end generate;

	ctrprc_gen_else : if USE_RISING_EDGE = '0' generate
		proc_clk : process(in_clk, in_reset)
			variable clk_ctr : natural range 0 to COUNTER - 1 := 0;
		begin
			-- asynchronous reset
			if in_reset = '1' then
				clk_ctr := 0;
				clk <= CLK_INIT;

			-- clock
			elsif falling_edge(in_clk) then
				if clk_ctr = COUNTER - 1 then
					clk <= not clk;
					clk_ctr := 0;
				else
					clk_ctr := clk_ctr + 1;
				end if;
			end if;
		end process;
	end generate;

end architecture;
