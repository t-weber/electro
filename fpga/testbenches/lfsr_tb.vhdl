--
-- lfsr test (sim)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date jan-2021
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/lfsr.vhdl lfsr_tb.vhdl  &&  ghdl -e --std=08 lfsr_tb lfsr_tb_impl
-- ghdl -r --std=08 lfsr_tb lfsr_tb_impl --vcd=lfsr_tb.vcd --stop-time=1us
-- gtkwave lfsr_tb.vcd
--

library ieee;
use ieee.std_logic_1164.all;


entity lfsr_tb is
	generic(
		constant BITS     : natural := 8;
		constant THEDELAY : time    := 10 ns
	);
end entity;


architecture lfsr_tb_impl of lfsr_tb is
	signal theclk : std_logic := '0';
	signal val    : std_logic_vector(BITS - 1 downto 0);

begin
	-- clock
	theclk <= not theclk after THEDELAY;


	---------------------------------------------------------------------------
	-- lfsr module
	---------------------------------------------------------------------------
	lfsrmod : entity work.lfsr
		generic map(
			BITS => BITS, SEED => "00000101"
		)
		port map(
			in_rst => '0', in_clk => theclk,
			in_seed => "00000101", in_setseed => '0',
			out_val => val, in_nextval => '1'
		);
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- debug output
	---------------------------------------------------------------------------
	report_proc : process(theclk)
	begin
		if rising_edge(theclk) then
			report "clk = " & std_logic'image(theclk) &
			       ", val = " & to_hstring(val);
		end if;
	end process;
        ---------------------------------------------------------------------------
end architecture;
