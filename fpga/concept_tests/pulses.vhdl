--
-- testing timing pulses (to avoid clock dividers)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 14-dec-2025
-- @license see 'LICENSE' file
--
-- ghdl -a --std=08 ../lib/clock/clkgen.vhdl pulses.vhdl  &&  ghdl -e --std=08 pulses pulses_arch
-- ghdl -r --std=08 pulses pulses_arch --vcd=pulses.vcd --stop-time=50us
-- gtkwave pulses.vcd --rcvar "do_initial_zoom_fit yes"
--

library ieee;
use ieee.std_logic_1164.all;


entity pulses is
end entity;


architecture pulses_arch of pulses is
	-- clock
	constant CLK_DELAY : time := 1.0 us;
	constant MAIN_CLK_HZ : natural := 1_000_000;
	constant SLOW_CLK_HZ : natural :=   250_000;

	signal clk : std_logic := '0';
	signal slow_clk : std_logic := '0';
	signal pulse_re, pulse_fe : std_logic := '0';

	-- reset
	constant RESET_DELAY : time := 1.5 us;
	signal rst : std_logic := '1';

begin
	-- main clock
	clk <= not clk after CLK_DELAY / 2;



	--
	-- clock divider
	--
	slow_clkgen : entity work.clkgen
		generic map(MAIN_HZ => MAIN_CLK_HZ, CLK_HZ => SLOW_CLK_HZ,
			CLK_INIT => '1', CLK_SHIFT => '0')
		port map(in_clk => clk, in_reset => rst, out_clk => slow_clk);



	--
	-- clock pulse at rising edge
	--
	slow_clkpulses_re : process(clk, rst) is
		-- pulse timer
		constant PULSE_DELAY : natural := MAIN_CLK_HZ / SLOW_CLK_HZ - 1;
		variable pulse_ctr : natural range 0 to PULSE_DELAY := 0;
	begin
		if rst = '1' then
			pulse_ctr := 0;
			pulse_re <= '0';

		elsif rising_edge(clk) then
			pulse_re <= '0';
			-- wait one cycle
			if pulse_ctr = PULSE_DELAY then
				pulse_re <= '1';
				pulse_ctr := 0;
			else
				pulse_ctr := pulse_ctr + 1;
			end if;
		end if;
	end process;



	--
	-- clock pulse at falling edge
	--
	slow_clkpulses_fe : process(clk, rst) is
		-- pulse timer
		constant PULSE_DELAY : natural := MAIN_CLK_HZ / SLOW_CLK_HZ;
		variable pulse_ctr : natural range 0 to PULSE_DELAY := 0;

		variable fsm_state : natural range 0 to 1 := 0;
	begin
		if rst = '1' then
			fsm_state := 0;
			pulse_ctr := 0;
			pulse_fe <= '0';

		elsif rising_edge(clk) then
			pulse_fe <= '0';
			case fsm_state is
				when 0 =>  -- wait half a cycle initially
					if pulse_ctr = PULSE_DELAY/2 - 1 then
						fsm_state := 1;
						pulse_ctr := 0;
					else
						pulse_ctr := pulse_ctr + 1;
					end if;
				when 1 =>  -- wait one cycle
					if pulse_ctr = PULSE_DELAY - 1 then
						pulse_fe <= '1';
						pulse_ctr := 0;
					else
						pulse_ctr := pulse_ctr + 1;
					end if;
			end case;
		end if;
	end process;



	--
	-- init process
	--
	init_proc : process is
	begin
		rst <= '1';
		wait for RESET_DELAY;
		rst <= '0';

		wait;
	end process;



	--
	-- debug output
	--
	report_proc : process(clk, rst) is
	begin
		report "t = "        & time'image(now) & ", "
			 & "rst = "      & std_logic'image(rst) & ", "
			 & "clk = "      & std_logic'image(clk) & ", "
			 & "slow_clk = " & std_logic'image(slow_clk) & ", "
			 & "pulse_re = " & std_logic'image(pulse_re) & ", "
			 & "pulse_fe = " & std_logic'image(pulse_fe);
	end process;

end architecture;
