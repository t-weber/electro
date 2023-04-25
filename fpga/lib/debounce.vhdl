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
		constant STABLE_TICKS : natural := 50;
		constant STABLE_TICKS_BITS : natural := 7  -- ceil(log2(STABLE_TICKS)) + 1
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



--                     1       -----
-- debounces a switch:        |
--                     0 -----
architecture debounce_switch_impl of debounce is
	-- number of steps to sample in shift register
	constant NUM_STEPS : natural := 3;

	signal shiftreg : std_logic_vector(0 to NUM_STEPS-1);
	signal signal_changed : std_logic := '0';
	signal debounced, debounced_next : std_logic;
	signal stable_counter, stable_counter_next
		: std_logic_vector(STABLE_TICKS_BITS-1 downto 0) := (others => '0');
begin

	-- has the signal toggled?
	signal_changed <= shiftreg(0) xor shiftreg(1);

	-- output the debounced signal
	out_debounced <= debounced;

	-- count the cycles the signal has been stable
	stable_counter_next <= inc_logvec(stable_counter, 1);
	
	
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
				stable_counter <= stable_counter_next;
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



--                     1       -----
-- debounces a button:        |     |
--                     0 -----       -----
architecture debounce_button_impl of debounce is
	type t_btnstate is (NotPressed, Pressed, Released);
	signal btnstate, btnstate_next : t_btnstate := NotPressed;

	signal debounced, debounced_next : std_logic := '0';
	signal stable_counter, stable_counter_next
		: std_logic_vector(STABLE_TICKS_BITS-1 downto 0) := (others => '0');
begin

	-- output the debounced signal
	out_debounced <= debounced;


	-- clock process
	clk_proc : process(in_clk)
	begin
		if rising_edge(in_clk) then
			btnstate <= btnstate_next;
			stable_counter <= stable_counter_next;
			debounced <= debounced_next;
		end if;
	end process;


	-- debouncing process
	debounce_proc : process(btnstate, stable_counter, in_signal)
	begin
                btnstate_next <= btnstate;
                stable_counter_next <= stable_counter;
		debounced_next <= '0';

		case btnstate is
			when NotPressed =>
				-- button being pressed?
				if in_signal = '1' then
					stable_counter_next <= inc_logvec(stable_counter, 1);
				else
					stable_counter_next <= (others => '0');
				end if;

				if to_int(stable_counter) = STABLE_TICKS then
					stable_counter_next <= (others => '0');
					btnstate_next <= Pressed;
				end if;

			when Pressed => 
				-- button being released?
				if in_signal = '0' then
					stable_counter_next <= inc_logvec(stable_counter, 1);
				else
					stable_counter_next <= (others => '0');
				end if;

				if to_int(stable_counter) = STABLE_TICKS then
					stable_counter_next <= (others => '0');
					btnstate_next <= Released;
				end if;

			when Released => 
				stable_counter_next <= (others => '0');
				btnstate_next <= NotPressed;
				debounced_next <= '1';
		end case;
	end process;

end architecture;
