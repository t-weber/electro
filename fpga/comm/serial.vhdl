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
		constant LOWBIT_FIRST : std_logic := '1';

		constant SERIAL_CLK_SHIFT : std_logic := '0'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- serial clock
		out_clk, out_ready : out std_logic;

		-- request next word
		out_next_word : out std_logic;

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

	-- serial clocks
	signal serial_clk, serial_clk_shifted, serial_clk_data : std_logic := '1';

	-- bit counter
	signal bit_ctr, next_bit_ctr : natural range 0 to BITS-1 := 0;

	-- bit counter with correct ordering
	signal actual_bit_ctr : natural range 0 to BITS-1 := 0;

	-- parallel input buffer (FPGA -> IC)
	signal parallel_fromfpga, next_parallel_fromfpga
		: std_logic_vector(BITS-1 downto 0) := (others => '0');

	-- serial output buffer (FPGA -> IC)
	signal serial_fromfpga : std_logic := SERIAL_DATA_INACTIVE;

	-- parallel output buffer (IC -> FPGA)
	signal parallel_tofpga, next_parallel_tofpga
		: std_logic_vector(BITS-1 downto 0) := (others => '0');

begin
	--
	-- generate serial clocks
	--
	serial_clkgen : entity work.clkgen
		generic map(MAIN_HZ => MAIN_HZ, CLK_HZ => SERIAL_HZ,
			CLK_INIT => '1')
		port map(in_clk => in_clk, in_reset => in_reset,
			out_clk => serial_clk);

	gen_clk : if SERIAL_CLK_SHIFT = '1' generate
		serial_clkgen_shifted : entity work.clkgen
			generic map(MAIN_HZ => MAIN_HZ, CLK_HZ => SERIAL_HZ,
				CLK_INIT => '1', CLK_SHIFT => '1')
			port map(in_clk => in_clk, in_reset => in_reset,
				out_clk => serial_clk_shifted);

		-- data clock with a falling edge in the middle of the
		-- inactive phase of the serial clock
		serial_clk_data <= serial_clk_shifted
			when serial_clk = SERIAL_CLK_INACTIVE
			else SERIAL_CLK_INACTIVE;

	else generate
		serial_clk_data <= serial_clk;
	end generate;


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
	-- state and data flip-flops for serial clock
	--
	serial_ff : process(serial_clk_data, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			serial_state <= Ready;

			-- counter register
			bit_ctr <= 0;

			-- parallel data register
			parallel_fromfpga <= (others => '0');
			parallel_tofpga <= (others => '0');

		-- clock
		elsif falling_edge(serial_clk_data) then
		--elsif rising_edge(serial_clk_data) then
			-- state register
			serial_state <= next_serial_state;

			-- counter register
			bit_ctr <= next_bit_ctr;

			-- parallel data register
			parallel_fromfpga <= next_parallel_fromfpga;
			parallel_tofpga <= next_parallel_tofpga;
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
		in_parallel, parallel_fromfpga)
	begin
		next_parallel_fromfpga <= parallel_fromfpga;

		if in_enable = '1' then
			next_parallel_fromfpga <= in_parallel;
		end if;
	end process;


	--
	-- buffer output with the chosen bit ordering (FPGA -> IC)
	--
	serial_fromfpga <= parallel_fromfpga(actual_bit_ctr);


	--
	-- output serial data (FPGA -> IC)
	--
	out_serial <= serial_fromfpga
		when serial_state = Transmit
		else SERIAL_DATA_INACTIVE;


	--
	-- buffer serial input (IC -> FPGA)
	--
	proc_in : process(in_serial, parallel_tofpga,
		serial_state, actual_bit_ctr)
	begin
		-- defaults
		next_parallel_tofpga <= parallel_tofpga;

		if serial_state = Transmit then
			next_parallel_tofpga(actual_bit_ctr) <= in_serial;
		end if;
	end process;


	--
	-- output read parallel data (IC -> FPGA)
	--
	out_parallel <= parallel_tofpga;


	--
	-- state combinatorics
	--
	proc_comb : process(in_enable, serial_state, bit_ctr)
	begin
		-- defaults
		next_serial_state <= serial_state;
		next_bit_ctr <= bit_ctr;

		out_next_word <= '0';
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
					out_next_word <= '1';
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
