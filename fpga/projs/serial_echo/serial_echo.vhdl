--
-- serial controller test (test: screen /dev/ttyUSB0 9600)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 16-jun-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;


entity main is
	port
	(
		-- main clock
		clock_50_b7a : in std_logic;

		-- serial interface
		uart_tx : out std_logic;
		uart_rx : in std_logic;

		-- 7-segment displays
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0);

		-- leds
		ledr : out std_logic_vector(6 downto 0);

		-- button
		key : in std_logic_vector(0 downto 0)
	);
end main;



architecture main_impl of main is
	constant BITS      : natural := 8;
	constant MAIN_HZ   : natural := 50_000_000;
	constant SERIAL_HZ : natural := 9_600;

	type t_state is
	(
		Idle, ReceiveData, TransmitData
	);
	signal state, next_state : t_state := Idle;

	signal start_tx, ready_tx : std_logic := '0';
	signal start_rx, ready_rx : std_logic := '0';
	signal error_rx : std_logic := '0';

	signal word_finished_tx, last_word_finished_tx : std_logic := '0';
	signal word_finished_rx, last_word_finished_rx : std_logic := '0';
	signal bus_cycle_tx_next, bus_cycle_rx_next : std_logic := '0';

	signal data_tx, next_data_tx : std_logic_vector(BITS-1 downto 0) := (others => '0');
	signal data_rx : std_logic_vector(BITS-1 downto 0) := (others => '0');

	signal rst : std_logic := '0';

begin

	-- seven segment displays
	sevenseg_tx0 : entity work.sevenseg
		generic map(ZERO_IS_ON => '1', INVERSE_NUMBERING => '1')
		port map(in_digit => data_tx(3 downto 0), out_leds => hex0);
	sevenseg_tx1 : entity work.sevenseg
		generic map(ZERO_IS_ON => '1', INVERSE_NUMBERING => '1')
		port map(in_digit => data_tx(7 downto 4), out_leds => hex1);
	sevenseg_rx0 : entity work.sevenseg
		generic map(ZERO_IS_ON => '1', INVERSE_NUMBERING => '1')
		port map(in_digit => data_rx(3 downto 0), out_leds => hex2);
	sevenseg_rx1 : entity work.sevenseg
		generic map(ZERO_IS_ON => '1', INVERSE_NUMBERING => '1')
		port map(in_digit => data_rx(7 downto 4), out_leds => hex3);

	-- serial transmitter
	serial_tx_ent : entity work.serial_async_tx
		generic map(BITS => BITS,
			MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ)
		port map(
			in_clk => clock_50_b7a, in_reset => rst,
			in_enable => start_tx, out_ready => ready_tx,
			out_serial => uart_tx, in_parallel => data_tx,
			out_next_word => word_finished_tx);

	-- serial receiver
	serial_rx_ent : entity work.serial_async_rx
		generic map(BITS => BITS,
			MAIN_HZ => MAIN_HZ, SERIAL_HZ => SERIAL_HZ)
		port map(
			in_clk => clock_50_b7a, in_reset => rst,
			in_enable => start_rx, out_ready => ready_rx,
			out_error => error_rx,
			in_serial => uart_rx, out_parallel => data_rx,
			out_word_finished => word_finished_rx);


	bus_cycle_tx_next <= (not word_finished_tx) and last_word_finished_tx;
	bus_cycle_rx_next <= (not word_finished_rx) and last_word_finished_rx;


	-- inputs and outputs
	ledr(0) <= start_tx;
	ledr(1) <= ready_tx;
	ledr(2) <= bus_cycle_tx_next;
	ledr(3) <= start_rx;
	ledr(4) <= ready_rx;
	ledr(5) <= bus_cycle_rx_next;
	ledr(6) <= error_rx;

	rst <= not key(0);


	--
	-- state flip-flops
	--
	ff : process(clock_50_b7a, rst)
	begin
		if rst = '1' then
			state <= Idle;
			data_tx <= (others => '0');
			last_word_finished_tx <= '0';
			last_word_finished_rx <= '0';

		elsif rising_edge(clock_50_b7a) then
			state <= next_state;
			data_tx <= next_data_tx;
			last_word_finished_tx <= word_finished_tx;
			last_word_finished_rx <= word_finished_rx;
		end if;
	end process;


	-- state combinatorics
	comb : process(state, data_tx, data_rx,
		bus_cycle_tx_next, bus_cycle_rx_next)
	begin
		 next_state <= state;
		 next_data_tx <= data_tx;

		 start_rx <= '0';
		 start_tx <= '0';

		 case state is
				when Idle =>
					start_rx <= '1';
					if bus_cycle_rx_next = '1' then
						next_state <= ReceiveData;
					end if;

				when ReceiveData =>
					start_rx <= '1';
					next_data_tx <= data_rx;
					next_state <= TransmitData;

				when TransmitData =>
					start_tx <= '1';
					if bus_cycle_tx_next = '1' then
						next_state <= Idle;
					end if;
		 end case;
	end process;

end main_impl;
