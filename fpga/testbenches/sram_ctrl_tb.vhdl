--
-- timing test for sram module (sim)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date feb-2021, feb-2024
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../mem/sram_ctrl.vhdl  &&  ghdl -a --std=08 sram_ctrl_tb.vhdl  &&  ghdl -e --std=08 sram_ctrl_tb sram_ctrl_tb_impl
-- ghdl -r --std=08 sram_ctrl_tb sram_ctrl_tb_impl --vcd=sram_ctrl_tb.vcd --stop-time=100ns
-- gtkwave sram_ctrl_tb.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;



entity sram_ctrl_tb is
	generic
	(
		-- main clock
		constant CLKDELAY : time := 2.5 ns;

		-- clock with modified duty cycle
		--constant CLK2SHIFT : time := 0 ns;
		--constant CLK2DUTY : time := 4 ns;

		-- address and data widths
		constant ADDR_WIDTH : natural := 8;
		constant DATA_WIDTH : natural := 8
	);
end entity;



architecture sram_ctrl_tb_impl of sram_ctrl_tb is
	signal theclk  : std_logic := '1';
	--signal theclk_mod : std_logic := '1';

	-- states
	type t_state is (
		ReadTest1a, ReadTest1b,
		ReadTest2a, ReadTest2b,
		WriteTest1a, WriteTest1b,
		Finished);
	signal state, state_next : t_state := ReadTest1a;

	signal enable, write_enable : std_logic := '0';

	signal addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal in_data, out_data : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal ready : std_logic;
begin

	---------------------------------------------------------------------------
	-- clocks
	---------------------------------------------------------------------------
	theclk <= not theclk after CLKDELAY;

	--
	-- clock with shorter duty cycle
	--
	--proc_modclk : process
	--begin
	--	loop
	--		wait for CLK2SHIFT;
	--		theclk_mod <= '1';
	--
	--		wait for CLK2DUTY;
	--		theclk_mod <= '0';
	--
	--		wait for CLKDELAY*2 - CLK2DUTY - CLK2SHIFT;
	--	end loop;
	--end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- state machine
	---------------------------------------------------------------------------
	proc_ff : process(theclk) is
	begin
		-- clock
		if rising_edge(theclk) then
			state <= state_next;
		end if;
	end process;


	--
	-- test input sequence
	--
	proc_test : process(all)
	begin
		-- defaults
		state_next <= state;

		enable <= '0';
		write_enable <= '0';
		addr <= (others => '0');
		in_data <= (others => 'Z');

		case state is
			when ReadTest1a =>
				--wait for 2 ns;
				enable <= '1';
				addr <= x"12";

				if ready = '0' then
					state_next <= ReadTest1b;
				end if;

			when ReadTest1b =>
				addr <= x"12";

				if ready = '1' then
					state_next <= ReadTest2a;
				end if;

			when ReadTest2a =>
				--wait for CLKDELAY*5;
				enable <= '1';
				addr <= x"34";

				if ready = '0' then
					state_next <= ReadTest2b;
				end if;

			when ReadTest2b =>
				addr <= x"34";

				if ready = '1' then
					state_next <= WriteTest1a;
				end if;

			when WriteTest1a =>
				--wait for CLKDELAY*5;
				enable <= '1';
				write_enable <= '1';
				addr <= x"ab";
				in_data <= x"78";

				if ready = '0' then
					state_next <= WriteTest1b;
				end if;

			when WriteTest1b =>
				write_enable <= '1';
				addr <= x"ab";
				in_data <= x"78";

				if ready = '1' then
					state_next <= Finished;
				end if;

			when Finished =>
				report "==== FINISHED ====";
		end case;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- debug output
	---------------------------------------------------------------------------
	--report_proc : process(theclk, theclk_mod)
	report_proc : process(theclk)
	begin
		report  lf &
			"clk = " & std_logic'image(theclk) &
			--", clk_mod = " & std_logic'image(theclk_mod) &
			", state = " & t_state'image(state) &
			", addr = " & to_hstring(addr) &
			", in_data = " & to_hstring(in_data) &
			", out_data = " & to_hstring(out_data) &
			", ready = " & std_logic'image(ready);
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- sram controller module
	---------------------------------------------------------------------------
	mod_sram_ctrl : entity work.sram_ctrl
		generic map(
			ADDR_WIDTH => ADDR_WIDTH, DATA_WIDTH => DATA_WIDTH
		)
		port map(
			in_clk => theclk, --in_clk_mod => theclk_mod,
			in_reset => '0', in_start => enable, in_write => write_enable,
			in_addr => addr, in_data => in_data,
			out_data => out_data, out_ready => ready
		);
	---------------------------------------------------------------------------
end architecture;
