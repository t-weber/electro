--
-- debounces a signal (e.g. a switch)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 22-april-2023
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;


entity debounce is
	generic(
		-- number of clock ticks to consider the signal stable
		constant STABLE_TICKS : natural := 32;
		constant STABLE_TICKS_BITS : natural := 6  -- log2(STABLE_TICKS) + 1
	);

	port(
		-- clock
		in_clk : in std_logic;

		-- signal to debounce
		in_signal : in std_logic;

		-- debounced signal
		out_debounced : out std_logic
	);
end entity;


architecture debounce_switch_impl of debounce is
	-- number of steps to sample in shift register
	constant NUM_STEPS : natural := 3;

	signal shiftreg : std_logic_vector(0 to NUM_STEPS-1);
	signal signal_changed : std_logic;
	signal debounced, debounced_next : std_logic;
	signal stable_counter, next_stable_counter : std_logic_vector(STABLE_TICKS_BITS-1 downto 0) := (others => '0');
begin

	-- has the signal toggled?
	signal_changed <= shiftreg(0) xor shiftreg(1);

	-- output the debounced signal
	out_debounced <= debounced;

	-- count the cycles the signal has been stable
	next_stable_counter <= inc_logvec(stable_counter, 1);
	
	
	-- clock process
	clk_proc : process(in_clk) begin
		if rising_edge(in_clk) then
			-- write signal in shift register
			shiftreg(0) <= in_signal;
			shiftloop: for i in 1 to NUM_STEPS-1 loop
				shiftreg(i) <= shiftreg(i-1);
			end loop;
			
			-- count the cycles the signal has been stable
			if(signal_changed = '1') then
				stable_counter <= (others => '0');
			else
				stable_counter <= next_stable_counter;
			end if;
			
			debounced <= debounced_next;
		end if;
	end process;
	
	
	-- output sampling process
	out_proc : process(stable_counter, debounced, shiftreg(NUM_STEPS-1)) begin
		-- keep value
		debounced_next <= debounced;

		-- if the signal has been stable, sample a new value
		if to_int(stable_counter) = STABLE_TICKS then
			debounced_next <= shiftreg(NUM_STEPS-1);
		end if;
	end process;
	
end architecture;
