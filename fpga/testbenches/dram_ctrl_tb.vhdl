--
-- test for dram module
-- @author Tobias Weber (orcid: 0000-0002-7230-1932)
-- @date 7 September 2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/mem/dram_ctrl.vhdl dram_ctrl_tb.vhdl  &&  ghdl -e --std=08 dram_ctrl_tb dram_ctrl_tb_impl
-- ghdl -r --std=08 dram_ctrl_tb dram_ctrl_tb_impl --vcd=dram_ctrl_tb.vcd --stop-time=500ns
-- gtkwave dram_ctrl_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;



entity dram_ctrl_tb is end entity;



architecture dram_ctrl_tb_impl of dram_ctrl_tb is
	-- main clock
	constant CLK_DELAY : time    := 20 ns;
	constant CLK_HZ    : natural := 50_000_000;

	-- address and data widths
	constant ADDR_WIDTH : natural := 10;
	constant DATA_WIDTH : natural := 32;
	constant DATA_BYTES : natural := DATA_WIDTH / 8;


	-- clock and reset
	signal clk, rst : std_logic := '0';

	-- states
	type t_state is (
		Reset, Idle
	);

	signal state, next_state : t_state := Reset;

	signal dram_clk, dram_clk_n : std_logic;
	signal dram_clk_ena  : std_logic_vector(1 downto 0);
	signal dram_cs_n     : std_logic_vector(1 downto 0);
	signal dram_cmd_addr : std_logic_vector(ADDR_WIDTH - 1 downto 0);
	signal dram_strobe   : std_logic_vector(DATA_BYTES - 1 downto 0) := (others => 'Z');
	signal dram_strobe_n : std_logic_vector(DATA_BYTES - 1 downto 0) := (others => 'Z');
	signal dram_data     : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => 'Z');

begin

	---------------------------------------------------------------------------
	-- clock
	---------------------------------------------------------------------------
	clk <= not clk after CLK_DELAY;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- state machine
	---------------------------------------------------------------------------
	proc_ff : process(clk) is
	begin
		-- clock
		if rising_edge(clk) then
			state <= next_state;
		end if;
	end process;


	--
	-- test input sequence
	--
	proc_test : process(all)
	begin
		-- defaults
		next_state <= state;
		rst <= '0';

		case state is
			when Reset =>
				rst <= '1';
				next_state <= Idle;

			when Idle =>

		end case;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- debug output
	---------------------------------------------------------------------------
	report_proc : process(clk)
	begin
		report lf &
			"clk = " & std_logic'image(clk) &
			", state = " & t_state'image(state) &
			", dram_clk = " & std_logic'image(dram_clk) &
			", dram_clk_ena = " & to_string(dram_clk_ena) &
			", dram_cs_n = " & to_string(dram_cs_n) &
			", dram_cmd_addr = " & to_string(dram_cmd_addr) &
			", dram_strobe = " & to_string(dram_strobe) &
			", dram_data = " & to_hstring(dram_data);
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- dram controller module
	---------------------------------------------------------------------------
	mod_dram_ctrl : entity work.dram_ctrl
		generic map(
			CMD_ADDR_WIDTH => ADDR_WIDTH, DATA_WIDTH => DATA_WIDTH,
			DATA_BYTES => DATA_BYTES, CLK_HZ => CLK_HZ
		)
		port map(
			in_clk => clk, in_rst => rst,

			inout_dram_datastrobe => dram_strobe,
			inout_dram_datastrobe_n => dram_strobe_n,
			inout_dram_data => dram_data,
			out_dram_clk => dram_clk,
			out_dram_clk_n => dram_clk_n,
			out_dram_clk_enable => dram_clk_ena,
			out_dram_chipselect_n => dram_cs_n,
			--out_dram_datamask =>
			out_dram_cmd_addr => dram_cmd_addr
		);
	---------------------------------------------------------------------------
end architecture;
