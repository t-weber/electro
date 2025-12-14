--
-- serial controller for asynchronous interface (transmission)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 15-jun-2024
-- @license see 'LICENSE' file
--
-- references:
--   - https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter#Data_framing
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity serial_async_tx is
	generic(
		-- clocks
		constant MAIN_HZ   : natural := 50_000_000;
		constant SERIAL_HZ : natural := 9_600;

		-- inactive signals
		constant SERIAL_INACTIVE : std_logic := '1';
		constant SERIAL_START    : std_logic := '0';
		constant SERIAL_STOP     : std_logic := '1';

		-- word lengths
		constant BITS        : natural := 8;
		constant START_BITS  : natural := 1;
		constant PARITY_BITS : natural := 0;
		constant STOP_BITS   : natural := 1;

		constant LOWBIT_FIRST : std_logic := '1';
		constant EVEN_PARITY  : std_logic := '1'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- not currently transmitting
		out_ready : out std_logic;

		-- enable transmission
		in_enable : in std_logic;

		-- request next word (one cycle before current word is finished)
		out_next_word : out std_logic;
		-- current word finished
		out_word_finished : out std_logic;

		-- parallel input data (FPGA -> IC)
		in_parallel : in std_logic_vector(BITS - 1 downto 0);

		-- serial output data (FPGA -> IC)
		out_serial : out std_logic
	);
end entity;



architecture serial_async_tx_impl of serial_async_tx is
	-----------------------------------------------------------------------
	-- states and next state logic
	type t_tx_state is (
		Ready, TransmitData,
		TransmitStart, TransmitParity, TransmitStop
	);

	signal tx_state, next_tx_state : t_tx_state := Ready;
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	-- bit counter
	signal bit_ctr, next_bit_ctr : natural range 0 to BITS - 1 := 0;

	-- bit counter with correct ordering
	signal actual_bit_ctr : natural range 0 to BITS - 1 := 0;
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	-- serial clock
	signal serial_clk : std_logic := '0';
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	-- parallel input buffer (FPGA -> IC)
	signal parallel_fromfpga, next_parallel_fromfpga
		: std_logic_vector(BITS - 1 downto 0) := (others => '0');

	-- serial output buffer (FPGA -> IC)
	signal serial_fromfpga : std_logic := SERIAL_INACTIVE;

	signal parity, next_parity : std_logic := '0';
	signal request_word, next_request_word : std_logic := '0';
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	function state_after_ready(enable : std_logic)
		return t_tx_state
	is begin
		if enable = '0' then
			return Ready;
		end if;

		if START_BITS /= 0 then
			return TransmitStart;
		end if;

		return TransmitData;
	end function;

	function state_after_start(enable : std_logic)
		return t_tx_state
	is begin
		if enable = '0' then
			return Ready;
		end if;

		return TransmitData;
	end function;

	function state_after_stop(enable : std_logic)
		return t_tx_state
	is begin
		if enable = '0' then
			return Ready;
		end if;

		if START_BITS /= 0 then
			return TransmitStart;
		end if;

		return TransmitData;
	end function;

	function state_after_parity(enable : std_logic)
		return t_tx_state
	is begin
		if STOP_BITS /= 0 then
			return TransmitStop;
		end if;

		return state_after_stop(enable => enable);
	end function;

	function state_after_transmit(enable : std_logic)
		return t_tx_state
	is begin
		if PARITY_BITS /= 0 then
			return TransmitParity;
		end if;

		return state_after_parity(enable => enable);
	end function;
	-----------------------------------------------------------------------

begin
	-----------------------------------------------------------------------
	--
	-- generate serial clocks
	--
	serial_clkgen : entity work.clkgen
		generic map(MAIN_HZ => MAIN_HZ, CLK_HZ => SERIAL_HZ,
			CLK_INIT => '1')
		port map(in_clk => in_clk, in_reset => in_reset,
			out_clk => serial_clk);
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	--
	-- get bit counter with correct ordering
	--
	gen_ctr_1 : if LOWBIT_FIRST = '1' generate
		actual_bit_ctr <= bit_ctr;
	else generate
		actual_bit_ctr <= BITS - bit_ctr - 1;
	end generate;
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	--
	-- buffer output with the chosen bit ordering (FPGA -> IC)
	--
	serial_fromfpga <= parallel_fromfpga(actual_bit_ctr);


	--
	-- output serial data (FPGA -> IC)
	--
	out_serial <= serial_fromfpga when tx_state = TransmitData
		else SERIAL_START     when tx_state = TransmitStart
		else parity           when tx_state = TransmitParity
		else SERIAL_STOP      when tx_state = TransmitStop
		else SERIAL_INACTIVE;


	--
	-- register input parallel data (FPGA -> IC)
	--
	proc_input : process(in_enable,
		in_parallel, parallel_fromfpga)
	begin
		next_parallel_fromfpga <= parallel_fromfpga;

		if in_enable = '1' then
			next_parallel_fromfpga <= in_parallel;
		end if;
	end process;

	out_word_finished <= request_word;
	out_next_word <= next_request_word;

	out_ready <= '1' when tx_state = Ready else '0';
	-----------------------------------------------------------------------


	--
	-- state and data flip-flops for serial clock
	--
	serial_ff : process(serial_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			tx_state <= Ready;

			-- counter register
			bit_ctr <= 0;

			-- parallel data register
			parallel_fromfpga <= (others => '0');

			request_word <= '0';

			parity <= not EVEN_PARITY;

		-- clock
		elsif rising_edge(serial_clk) then
			-- state register
			tx_state <= next_tx_state;

			-- counter register
			bit_ctr <= next_bit_ctr;

			-- parallel data register
			parallel_fromfpga <= next_parallel_fromfpga;

			request_word <= next_request_word;

			parity <= next_parity;
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(in_enable, tx_state, bit_ctr)
	begin
		-- defaults
		next_tx_state <= tx_state;
		next_bit_ctr <= bit_ctr;
		next_request_word <= '0';

		report "** serial_async_tx: " & t_tx_state'image(tx_state) &
			", bit: " & integer'image(bit_ctr);

		-- state machine
		case tx_state is
			-- wait for enable signal
			when Ready =>
				next_bit_ctr <= 0;
				next_tx_state <= state_after_ready(enable => in_enable);

			-- transmit start bit(s)
			when TransmitStart =>
				-- end of word?
				if bit_ctr = START_BITS - 1 then
					next_bit_ctr <= 0;
					next_tx_state <= state_after_start(enable => in_enable);
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

			-- serialise parallel data
			when TransmitData =>
				-- end of word?
				if bit_ctr = BITS - 1 then
					next_request_word <= '1';
					next_bit_ctr <= 0;
					next_tx_state <= state_after_transmit(enable => in_enable);
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

			-- transmit parity bit(s)
			when TransmitParity =>
				-- end of word?
				if bit_ctr = PARITY_BITS - 1 then
					next_bit_ctr <= 0;
					next_tx_state <= state_after_parity(enable => in_enable);
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

			-- transmit stop bit(s)
			when TransmitStop =>
				-- end of word?
				if bit_ctr = STOP_BITS - 1 then
					next_bit_ctr <= 0;
					next_tx_state <= state_after_stop(enable => in_enable);
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

			-- default state
			when others =>
				next_tx_state <= Ready;
		end case;
	end process;


	--
	-- parity calculation
	--
	parity_comb : process(tx_state, parity,
		parallel_fromfpga, actual_bit_ctr)
	begin
		-- defaults
		next_parity <= parity;

		case tx_state is
			when Ready | TransmitStart | TransmitStop =>
				next_parity <= not EVEN_PARITY;

			when TransmitData =>
				if parallel_fromfpga(actual_bit_ctr) = '1' then
					next_parity <= not parity;
				end if;

			when others =>
				null;
		end case;
	end process;

end architecture;
