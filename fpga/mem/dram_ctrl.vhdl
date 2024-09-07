--
-- dram controller
-- @author Tobias Weber (orcid: 0000-0002-7230-1932)
-- @date 7 September 2024
-- @license see 'LICENSE' file
--
-- References:
--   - [manual] https://eu.mouser.com/datasheet/2/198/43LD16256A_32128A-1878872.pdf
--   - [manual-new] https://www.issi.com/WW/pdf/43-46LD32128B.pdf
--   - https://en.wikipedia.org/wiki/LPDDR
--

library ieee;
use ieee.std_logic_1164.all;
--use work.conv.all;



entity dram_ctrl is
	generic
	(
		-- address and data bus size
		constant CMD_ADDR_WIDTH : natural := 10;
		constant DATA_WIDTH     : natural := 32;
		constant DATA_BYTES     : natural := DATA_WIDTH / 8;

		-- clock frequency
		constant CLK_HZ         : natural := 100_000_000
	);

	port
	(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-----------------------------------------------------------------------
		-- dram interface
		inout_dram_datastrobe   : inout std_logic_vector(DATA_BYTES - 1 downto 0);
		inout_dram_datastrobe_n : inout std_logic_vector(DATA_BYTES - 1 downto 0);
		inout_dram_data         : inout std_logic_vector(DATA_WIDTH - 1 downto 0);

		out_dram_clk, out_dram_clk_n : out std_logic;
		out_dram_clk_enable          : out std_logic_vector(1 downto 0);
		out_dram_chipselect_n        : out std_logic_vector(1 downto 0);
		out_dram_datamask            : out std_logic_vector(DATA_BYTES - 1 downto 0);
		out_dram_cmd_addr            : out std_logic_vector(CMD_ADDR_WIDTH - 1 downto 0)
		-----------------------------------------------------------------------
	);
end dram_ctrl;



architecture dram_ctrl_impl of dram_ctrl is
	-- states
	type t_state is
	(
		Reset, Idle,
		NOP
	);
	signal state, next_state : t_state := Reset;

	signal on_rising_edge : std_logic := '1';

begin



-------------------------------------------------------------------------------
-- outputs
-------------------------------------------------------------------------------
out_dram_clk   <= in_clk;
out_dram_clk_n <= not in_clk;
-------------------------------------------------------------------------------



proc_ff : process(in_clk, in_rst)
begin
	if in_rst = '1' then
		state <= Reset;

	elsif rising_edge(in_clk) then
		state <= next_state;
		on_rising_edge <= '1';

	elsif falling_edge(in_clk) then
		on_rising_edge <= '0';

	end if;
end process;



proc_comb : process(state, on_rising_edge)
begin
	next_state <= state;

	out_dram_clk_enable   <= (others => '0');
	out_dram_chipselect_n <= (others => '1');
	out_dram_cmd_addr <= (others => '0');

	case state is
		when Reset =>
			next_state <= NOP;

		when Idle =>

		when NOP =>  -- [manual], p. 23
			next_state <= Idle;

			out_dram_clk_enable <= (others => '1');
			if on_rising_edge = '1' then
				out_dram_chipselect_n <= (others => '0');
				out_dram_cmd_addr <= (0 => '1', 1 => '1', 2 => '1', others => '0');
			end if;

	end case;
end process;



end architecture;
