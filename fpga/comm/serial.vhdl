--
-- serial controller for 3-wire protocol
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-nov-2023
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity serial is
	generic(
		-- clocks
		constant MAIN_HZ : natural := 50_000_000;
		constant SERIAL_HZ : natural := 10_000;

		-- inactive signals
		constant SERIAL_CLK_INACTIVE : std_logic := '1';
		constant SERIAL_DATA_INACTIVE : std_logic := '1';

		-- word length
		constant BITS : natural := 8;
		constant LOWBIT_FIRST : std_logic := '1'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- serial clock
		out_clk, out_ready : out std_logic;

		-- current word transmitted or received?
		out_word_finished : out std_logic;

		-- enable transmission
		in_enable : in std_logic;

		-- parallel input data (FPGA -> IC)
		in_parallel : in std_logic_vector(BITS-1 downto 0);

		-- serial output data (FPGA -> IC)
		out_serial : out std_logic;

		-- serial input data (IC -> FPGA)
		in_serial : in std_logic;

		-- parallel output data (IC -> FPGA)
		out_parallel : out std_logic_vector(BITS-1 downto 0)
	);
end entity;



architecture serial_impl of serial is
	-- states and next state logic
	type t_serial_state is ( Ready, Transmit );
	signal serial_state, next_serial_state : t_serial_state := Ready;

	-- serial clock
	signal serial_clk : std_logic := '1';

	-- bit counter
	signal bit_ctr, next_bit_ctr : natural range 0 to BITS-1 := 0;

	-- bit counter with correct ordering
	signal actual_bit_ctr : natural range 0 to BITS-1 := 0;

	-- parallel input buffer (FPGA -> IC)
	signal parallel_data, next_parallel_data
		: std_logic_vector(BITS-1 downto 0) := (others => '0');

	-- serial output buffer (FPGA -> IC)
	signal serial_buf_out : std_logic := SERIAL_DATA_INACTIVE;

	-- parallel output buffer (IC -> FPGA)
	signal parallel_buf_in, next_parallel_buf_in
		: std_logic_vector(BITS-1 downto 0) := (others => '0');

begin
	--
	-- generate serial clock
	--
	serial_clkgen : entity work.clkgen
		generic map(MAIN_HZ => MAIN_HZ, CLK_HZ => SERIAL_HZ,
			CLK_INIT => '1')
		port map(in_clk => in_clk, in_reset => in_reset,
			out_clk => serial_clk);


	--
	-- output serial clock
	--
	gen_outclk : if SERIAL_CLK_INACTIVE = '1' generate
		-- inactive '1' and trigger on falling edge
		out_clk <= serial_clk when serial_state = Transmit else '1';
	else generate
		-- inactive '0' and trigger on rising edge
		out_clk <= not serial_clk when serial_state = Transmit else '0';
	end generate;


	--
	-- state flip-flops for serial clock
	--
	serial_ff : process(serial_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			serial_state <= Ready;

			-- counter register
			bit_ctr <= 0;

		-- clock
		--elsif falling_edge(serial_clk) then
		elsif rising_edge(serial_clk) then
			-- state register
			serial_state <= next_serial_state;

			-- counter register
			bit_ctr <= next_bit_ctr;
		end if;
	end process;


	--
	-- state flip-flops for main clock
	--
	main_ff : process(in_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- parallel data register
			parallel_data <= (others => '0');
			parallel_buf_in <= (others => '0');

		-- clock
		--elsif falling_edge(in_clk) then
		elsif rising_edge(in_clk) then
			-- parallel data register
			parallel_data <= next_parallel_data;
			parallel_buf_in <= next_parallel_buf_in;
		end if;
	end process;


	--
	-- get bit counter with correct ordering
	--
	gen_ctr_1 : if LOWBIT_FIRST = '1' generate
		actual_bit_ctr <= bit_ctr;
	end generate;
	gen_ctr_0 : if LOWBIT_FIRST = '0' generate
		actual_bit_ctr <= BITS - bit_ctr - 1;
	end generate;


	--
	-- register input parallel data (FPGA -> IC)
	--
	proc_input : process(in_enable,
		in_parallel, parallel_data)
	begin
		next_parallel_data <= parallel_data;

		if in_enable = '1' then
			next_parallel_data <= in_parallel;
		end if;
	end process;


	--
	-- buffer output with the chosen bit ordering (FPGA -> IC)
	--
	serial_buf_out <= parallel_data(actual_bit_ctr);


	--
	-- output serial data (FPGA -> IC)
	--
	out_serial <= serial_buf_out
		when serial_state = Transmit
		else SERIAL_DATA_INACTIVE;


	--
	-- buffer serial input (IC -> FPGA)
	--
	proc_in : process(in_serial, parallel_buf_in,
		serial_state, actual_bit_ctr)
	begin
		-- defaults
		next_parallel_buf_in <= parallel_buf_in;

		if serial_state = Transmit then
			next_parallel_buf_in(actual_bit_ctr) <= in_serial;
		end if;
	end process;


	--
	-- output read parallel data (IC -> FPGA)
	--
	out_parallel <= parallel_buf_in;


	--
	-- state combinatorics
	--
	proc_comb : process(in_enable, serial_state, bit_ctr)
	begin
		-- defaults
		next_serial_state <= serial_state;
		next_bit_ctr <= bit_ctr;

		out_word_finished <= '0';
		out_ready <= '0';

		-- state machine
		case serial_state is
			-- wait for enable signal
			when Ready =>
				out_ready <= '1';
				next_bit_ctr <= 0;
				if in_enable = '1' then
					next_serial_state <= Transmit;
				end if;

			-- serialise parallel data
			when Transmit =>
				-- end of word?
				if bit_ctr = BITS - 1 then
					out_word_finished <= '1';
					next_bit_ctr <= 0;
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

				-- enable signal not active anymore?
				if in_enable = '0' then
					next_serial_state <= Ready;
				end if;

			-- default state
			when others =>
				next_serial_state <= Ready;
		end case;
	end process;

end architecture;
