--
-- timed sequence test
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 24-may-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
--use work.conv.all;



entity tones is
	generic(
		-- clock
		constant MAIN_HZ : natural := 50_000_000;
		constant FREQ_BITS : natural := 16
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;
		in_enable : in std_logic;

		out_freq : out std_logic_vector(FREQ_BITS - 1 downto 0)
	);
end entity;



architecture tones_impl of tones is
	-- states
	type t_state is ( Reset, Idle,
		SeqData, SeqDuration, SeqDelay, SeqNext);

	signal state, next_state : t_state := Reset;

	-- counter for busy wait
	signal wait_counter, wait_counter_max : natural := 0;

	-- data struct
	type t_seq_freq is record
		freq     : std_logic_vector(FREQ_BITS - 1 downto 0);
		duration : natural;  -- time to keep frequency
		delay    : natural;  -- time to wait before next frequency
	end record;

	--
	-- tone sequence (see: tools/gentones/gentones.cpp)
	--   melody: https://en.wikipedia.org/wiki/Symphony_No._9_(Beethoven)#IV._Finale
	--   tuning: https://en.wikipedia.org/wiki/Equal_temperament
	--
	type t_seq_arr is array(0 to 57 - 1) of t_seq_freq;
	constant def_delay : natural := MAIN_HZ / 20;
	constant seq_arr : t_seq_arr := (
		-- sequence 1
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 0
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 1
		(freq => 16d"621", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 2

		-- sequence 2
		(freq => 16d"621", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 3
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 4
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 5
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 6

		-- sequence 3
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 7
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 8
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 9

		-- sequence 4
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 499, delay => def_delay), -- tone 10
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 166, delay => def_delay), -- tone 11
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 12

		-- sequence 5
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 13
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 14
		(freq => 16d"621", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 15

		-- sequence 6
		(freq => 16d"621", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 16
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 17
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 18
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 19

		-- sequence 7
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 20
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 21
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 22

		-- sequence 8
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 499, delay => def_delay), -- tone 23
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 166, delay => def_delay), -- tone 24
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 25

		-- sequence 9
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 26
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 27
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 28

		-- sequence 10
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 29
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 166, delay => def_delay), -- tone 30
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 166, delay => def_delay), -- tone 31
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 32
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 33

		-- sequence 11
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 34
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 166, delay => def_delay), -- tone 35
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 166, delay => def_delay), -- tone 36
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 37
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 38

		-- sequence 12
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 39
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 40
		(freq => 16d"310", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 41
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 42

		-- sequence 13
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 43
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 44
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 45
		(freq => 16d"621", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 46

		-- sequence 14
		(freq => 16d"621", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 47
		(freq => 16d"553", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 48
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 49
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 50

		-- sequence 15
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 665, delay => def_delay), -- tone 51
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 52
		(freq => 16d"522", duration => MAIN_HZ / 1000 * 333, delay => def_delay), -- tone 53

		-- sequence 16
		(freq => 16d"465", duration => MAIN_HZ / 1000 * 499, delay => def_delay), -- tone 54
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 166, delay => def_delay), -- tone 55
		(freq => 16d"414", duration => MAIN_HZ / 1000 * 665, delay => def_delay)  -- tone 56
	);

	signal seq_freq, next_seq_freq : std_logic_vector(FREQ_BITS - 1 downto 0);
	signal seq_duration, next_seq_duration : natural;
	signal seq_delay, next_seq_delay : natural;
	signal seq_cycle, next_seq_cycle : natural range 0 to seq_arr'length := 0;

begin

	-- data output
	out_freq <= seq_freq;


	--
	-- state flip-flops
	--
	proc_ff : process(in_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			state <= Reset;

			-- sequence data, duration, and delay
			seq_freq <= (others => '0');
			seq_duration <= 0;
			seq_delay <= 0;

			-- command counter
			seq_cycle <= 0;

			-- timer register
			wait_counter <= 0;

		-- clock
		elsif rising_edge(in_clk) then
			-- state register
			state <= next_state;

			-- sequence data
			seq_freq <= next_seq_freq;
			seq_duration <= next_seq_duration;
			seq_delay <= next_seq_delay;

			-- command counter
			seq_cycle <= next_seq_cycle;

			-- timer register
			if wait_counter = wait_counter_max then
				-- reset timer counter
				wait_counter <= 0;
			else
				-- next timer counter
				wait_counter <= wait_counter + 1;
			end if;
		end if;
	end process;



	--
	-- state combinatorics
	--
	proc_comb : process(
		in_reset, in_enable,
		state, seq_cycle,
		seq_freq, seq_duration, seq_delay,
		wait_counter, wait_counter_max)
	begin
		-- defaults
		next_state <= state;
		next_seq_freq <= seq_freq;
		next_seq_duration <= seq_duration;
		next_seq_delay <= seq_delay;
		next_seq_cycle <= seq_cycle;
		wait_counter_max <= 0;


		-- fsm
		case state is

			--
			-- reset
			--
			when Reset =>
				if in_enable = '1' then
					next_state <= SeqData;
				end if;

			--
			-- setup finished
			--
			when Idle =>
				null;

			----------------------------------------------------------------------
			-- sequence
			----------------------------------------------------------------------
			when SeqData =>
				-- write the rest of the value bits
				next_seq_freq <= seq_arr(seq_cycle).freq;
				next_seq_duration <= seq_arr(seq_cycle).duration;
				next_seq_delay <= seq_arr(seq_cycle).delay;
				next_state <= SeqDuration;

			when SeqDuration =>
				wait_counter_max <= seq_duration;
				if wait_counter = wait_counter_max then
					next_state <= SeqDelay;
				end if;

			when SeqDelay =>
				next_seq_freq <= (others => '0');
				wait_counter_max <= seq_delay;
				if wait_counter = wait_counter_max then
					next_state <= SeqNext;
				end if;

			when SeqNext =>
				if seq_cycle + 1 = seq_arr'length then
					-- at end of sequence
					next_state <= Idle;
					next_seq_cycle <= 0;
				else
					-- next sequence item
					next_seq_cycle <= seq_cycle + 1;
					next_state <= SeqData;
				end if;
			----------------------------------------------------------------------

			when others =>
				next_state <= Reset;
		end case;
	end process;

end architecture;
