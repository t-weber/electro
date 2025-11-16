--
-- serial controller for asynchronous interface (receiver)
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


entity serial_async_rx is
	generic(
		-- clocks
		constant MAIN_HZ   : natural := 50_000_000;
		constant SERIAL_HZ : natural := 9_600;

		-- sampling clock multiplier
		constant CLK_MULTIPLE : natural := 8;
		-- portion of multiplier to check for the last start bit
		constant CLK_TOCHECK  : natural := 6;

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
		constant EVEN_PARITY  : std_logic := '1';

		constant STOP_ON_ERROR : std_logic := '0'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- not currently receiving
		out_ready : out std_logic;

		-- reception error
		out_error : out std_logic;

		-- request next word (one cycle before current word is finished)
		out_next_word : out std_logic;
		-- current word finished
		out_word_finished : out std_logic;

		-- enable transmission
		in_enable : in std_logic;

		-- serial input data (IC -> FPGA)
		in_serial : in std_logic;

		-- parallel output data (IC -> FPGA)
		out_parallel : out std_logic_vector(BITS-1 downto 0)
	);
end entity;



architecture serial_async_rx_impl of serial_async_rx is
	-----------------------------------------------------------------------
	-- states and next state logic
	type t_rx_state is (
		Ready, Error, WaitCycle,
		ReceiveData,
		ReceiveStartCont, ReceiveStart,
		ReceiveParity, ReceiveStop
	);

	signal rx_state, next_rx_state : t_rx_state := Ready;
	signal state_after_wait, next_state_after_wait : t_rx_state := Ready;
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	-- bit counter
	signal bit_ctr, next_bit_ctr, last_bit_ctr : natural range 0 to BITS-1 := 0;

	-- bit counter with correct ordering
	signal actual_bit_ctr, last_actual_bit_ctr : natural range 0 to BITS-1 := 0;

	-- clock multipe counter
	signal multi_ctr, next_multi_ctr : natural range 0 to 3/2*CLK_MULTIPLE-1 := 0;
	signal multi_ctr_towait, next_multi_ctr_towait : natural range 0 to 3/2*CLK_MULTIPLE-1 := 0;
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	-- serial clock
	signal serial_clk : std_logic := '0';
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	-- parallel output buffer (IC -> FPGA)
	signal parallel_tofpga, next_parallel_tofpga
		: std_logic_vector(BITS-1 downto 0) := (others => '0');

	signal request_word, next_request_word : std_logic := '0';
	signal parity, next_parity : std_logic := '0';
	signal calc_parity, next_calc_parity : std_logic := '0';
	-----------------------------------------------------------------------

	-----------------------------------------------------------------------
	function state_after_ready(enable : std_logic)
		return t_rx_state
	is begin
		if enable = '0' then
			return Ready;
		end if;

		if START_BITS /= 0 then
			return ReceiveStartCont;
		end if;

		return ReceiveData;
	end function;

	function state_after_start(enable : std_logic)
		return t_rx_state
	is begin
		if enable = '0' then
			return Ready;
		end if;

		return ReceiveData;
	end function;

	function state_after_stop(enable : std_logic)
		return t_rx_state
	is begin
		if enable = '0' then
			return Ready;
		end if;

		if START_BITS /= 0 then
			return ReceiveStart;
		end if;

		return ReceiveData;
	end function;

	function state_after_parity(enable : std_logic)
		return t_rx_state
	is begin
		if STOP_BITS /= 0 then
			return ReceiveStop;
		end if;

		return state_after_stop(enable => enable);
	end function;

	function state_after_receive(enable : std_logic)
		return t_rx_state
	is begin
		if PARITY_BITS /= 0 then
			return ReceiveParity;
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
		generic map(
			MAIN_HZ => MAIN_HZ,
			CLK_HZ => SERIAL_HZ * CLK_MULTIPLE,
			CLK_INIT => '1')
		port map(
			in_clk => in_clk, in_reset => in_reset,
			out_clk => serial_clk);
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	--
	-- get bit counter with correct ordering
	--
	gen_ctr_1 : if LOWBIT_FIRST = '1' generate
		actual_bit_ctr <= bit_ctr;
		last_actual_bit_ctr <= last_bit_ctr;
	else generate
		actual_bit_ctr <= BITS - bit_ctr - 1;
		last_actual_bit_ctr <= BITS - last_bit_ctr - 1;
	end generate;
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	--
	-- buffer serial input (IC -> FPGA)
	--
	proc_in : process(in_serial, parallel_tofpga,
		rx_state, actual_bit_ctr)
	begin
		-- defaults
		next_parallel_tofpga <= parallel_tofpga;

		if rx_state = ReceiveData then
			next_parallel_tofpga(actual_bit_ctr) <= in_serial;
		end if;
	end process;


	--
	-- output read parallel data (IC -> FPGA)
	--
	out_parallel <= parallel_tofpga;

	out_word_finished <= request_word;
	out_next_word <= next_request_word;
	out_ready <= '1' when rx_state = Ready else '0';
	out_error <= '1' when rx_state = Error else '0';
	-----------------------------------------------------------------------


	--
	-- state and data flip-flops for serial clock
	--
	serial_ff : process(serial_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state registers
			rx_state <= Ready;
			state_after_wait <= Ready;

			-- counter register
			bit_ctr <= 0;
			last_bit_ctr <= 0;
			multi_ctr <= 0;
			multi_ctr_towait <= 0;

			-- parity
			parity <= not EVEN_PARITY;
			calc_parity <= '0';

			-- parallel data register
			parallel_tofpga <= (others => '0');

			request_word <= '0';

		-- clock
		elsif falling_edge(serial_clk) then
		--elsif rising_edge(serial_clk) then
			-- state registers
			rx_state <= next_rx_state;
			state_after_wait <= next_state_after_wait;

			-- counter register
			last_bit_ctr <= bit_ctr;
			bit_ctr <= next_bit_ctr;
			multi_ctr <= next_multi_ctr;
			multi_ctr_towait <= next_multi_ctr_towait;

			-- parity
			parity <= next_parity;
			calc_parity <= next_calc_parity;

			-- parallel data register
			parallel_tofpga <= next_parallel_tofpga;

			request_word <= next_request_word;
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(in_enable, rx_state,
		bit_ctr, multi_ctr, multi_ctr_towait,
		state_after_wait, in_serial, parity)
	begin
		-- defaults
		next_rx_state <= rx_state;
		next_bit_ctr <= bit_ctr;
		next_multi_ctr <= multi_ctr;
		next_multi_ctr_towait <= multi_ctr_towait;
		next_state_after_wait <= state_after_wait;
		next_request_word <= '0';

		-- state machine
		case rx_state is
			-- wait for enable signal
			when Ready =>
				next_bit_ctr <= 0;
				next_rx_state <= state_after_ready(enable => in_enable);

			when Error =>
				next_bit_ctr <= 0;
				next_multi_ctr <= 0;

				if STOP_ON_ERROR = '0' then
					next_rx_state <= WaitCycle;
					next_state_after_wait <= Ready;
					next_multi_ctr_towait <=
						CLK_MULTIPLE - CLK_TOCHECK  -- remainder of this cycle
						+ CLK_MULTIPLE/2 - 2;       -- half of next cycle
				end if;

			-- move to the specified point of the next serial signal
			when WaitCycle =>
				-- also count in the clock cycle lost by changing states
				if multi_ctr = multi_ctr_towait then
					next_rx_state <= state_after_wait;
					next_multi_ctr <= 0;
				else
					next_multi_ctr <= multi_ctr + 1;
				end if;

			-- receive start bit(s), probing at every cycle
			-- until the given fraction of the last start bit
			when ReceiveStartCont =>
				if in_serial = SERIAL_START then
					-- at the given fraction of the last start bit?
					if multi_ctr = CLK_TOCHECK - 1 and bit_ctr = START_BITS - 1 then
						next_state_after_wait <= state_after_start(enable => in_enable);
						next_rx_state <= WaitCycle;
						next_multi_ctr_towait <=
							CLK_MULTIPLE - CLK_TOCHECK  -- remainder of this cycle
							+ CLK_MULTIPLE/2 - 2;       -- half of next cycle
						next_bit_ctr <= 0;
						next_multi_ctr <= 0;

					-- end of clock multiplier?
					elsif multi_ctr = CLK_MULTIPLE - 1 then
						next_multi_ctr <= 0;
						next_bit_ctr <= bit_ctr + 1;

					-- next clock multiplier
					else
						next_multi_ctr <= multi_ctr + 1;
					end if;
				else
					next_bit_ctr <= 0;
					next_multi_ctr <= 0;

					if in_enable = '0' then
						next_rx_state <= Ready;
					end if;
				end if;

			-- receive start bit(s), only probing once
			when ReceiveStart =>
				next_rx_state <= WaitCycle;
				next_multi_ctr_towait <= CLK_MULTIPLE - 2;
				next_multi_ctr <= 0;

				if in_serial = SERIAL_START then
					-- end of word?
					if bit_ctr = START_BITS - 1 then
						next_bit_ctr <= 0;
						next_state_after_wait <= state_after_start(enable => in_enable);
					else
						next_bit_ctr <= bit_ctr + 1;
						next_state_after_wait <= ReceiveStart;
					end if;
				else
					if in_enable = '0' then
						next_rx_state <= Ready;
					else
						next_state_after_wait <= ReceiveStart;
					end if;
				end if;

			-- receive serial data bits
			when ReceiveData =>
				next_rx_state <= WaitCycle;
				next_multi_ctr_towait <= CLK_MULTIPLE - 2;
				next_multi_ctr <= 0;

				-- end of word?
				if bit_ctr = BITS - 1 then
					next_request_word <= '1';
					next_bit_ctr <= 0;
					next_state_after_wait <= state_after_receive(enable => in_enable);
				else
					next_bit_ctr <= bit_ctr + 1;
					next_state_after_wait <= ReceiveData;
				end if;

			-- receive parity bit(s)
			when ReceiveParity =>
				if parity /= in_serial then
					next_rx_state <= Error;
				else
					next_rx_state <= WaitCycle;
					next_multi_ctr_towait <= CLK_MULTIPLE - 2;
					next_multi_ctr <= 0;
				end if;

				-- end of word?
				if bit_ctr = PARITY_BITS - 1 then
					next_bit_ctr <= 0;
					next_state_after_wait <= state_after_parity(enable => in_enable);
				else
					next_bit_ctr <= bit_ctr + 1;
					next_state_after_wait <= ReceiveParity;
				end if;

			-- receive stop bit(s)
			when ReceiveStop =>
				if in_serial = SERIAL_STOP then
					next_rx_state <= WaitCycle;
					next_multi_ctr_towait <= CLK_MULTIPLE - 2;
					next_multi_ctr <= 0;

					-- end of word?
					if bit_ctr = STOP_BITS - 1 then
						next_bit_ctr <= 0;
						next_state_after_wait <= state_after_stop(enable => in_enable);
					else
						next_bit_ctr <= bit_ctr + 1;
						next_state_after_wait <= ReceiveStop;
					end if;
				else
					next_rx_state <= Error;
				end if;

			-- default state
			when others =>
				next_rx_state <= Ready;
		end case;
	end process;


	--
	-- parity calculation
	--
	parity_comb : process(rx_state, parity, calc_parity,
		parallel_tofpga, last_actual_bit_ctr)
	begin
		-- defaults
		next_parity <= parity;
		next_calc_parity <= calc_parity;

		case rx_state is
			when Ready | ReceiveStartCont | ReceiveStart | ReceiveStop =>
				next_parity <= not EVEN_PARITY;

			when ReceiveData =>
				next_calc_parity <= '1';

			when others =>
				null;
		end case;

		if calc_parity = '1' then
			if parallel_tofpga(last_actual_bit_ctr) = '1' then
				next_parity <= not parity;
			end if;
			next_calc_parity <= '0';
		end if;

	end process;


end architecture;
