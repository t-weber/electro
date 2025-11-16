--
-- serial controller for 3-wire interface with
--   independent transmission and reception
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date aug-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity serial is
	generic(
		-- clocks
		constant MAIN_HZ   : natural := 50_000_000;
		constant SERIAL_HZ : natural := 10_000;

		-- inactive signals
		constant SERIAL_CLK_INACTIVE  : std_logic := '1';
		constant SERIAL_DATA_INACTIVE : std_logic := '1';

		-- word length
		constant BITS         : natural   := 8;
		constant LOWBIT_FIRST : std_logic := '1';

		-- signal triggers
		constant FROM_FPGA_FALLING_EDGE : std_logic := '1';
		constant TO_FPGA_FALLING_EDGE   : std_logic := '1';


		constant SERIAL_CLK_SHIFT : std_logic := '0'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- serial clock
		out_clk : out std_logic;

		-- request next word (one cycle before current word is finished)
		out_next_word_tofpga : out std_logic;
		out_next_word_fromfpga : out std_logic;

		-- enable transmission
		in_enable_tofpga : in std_logic;
		in_enable_fromfpga : in std_logic;

		-- parallel input data (FPGA -> IC)
		in_parallel : in std_logic_vector(BITS - 1 downto 0);

		-- serial output data (FPGA -> IC)
		out_serial : out std_logic;

		-- serial input data (IC -> FPGA)
		in_serial : in std_logic;

		-- parallel output data (IC -> FPGA)
		out_parallel : out std_logic_vector(BITS - 1 downto 0)
	);
end entity;



architecture serial_impl of serial is
	-- states and next state logic
	type t_serial_fromfpga_state is ( Ready, Transmit );
	signal serial_fromfpga_state, next_serial_fromfpga_state
		: t_serial_fromfpga_state := Ready;

	-- serial clocks
	signal serial_clk, serial_clk_shifted, serial_clk_data
		: std_logic := SERIAL_CLK_INACTIVE;

	-- bit counters
	signal bit_ctr_fromfpga, next_bit_ctr_fromfpga : natural range 0 to BITS - 1 := 0;
	signal bit_ctr_tofpga, next_bit_ctr_tofpga : natural range 0 to BITS - 1 := 0;

	-- bit counter with correct ordering
	signal actual_bit_ctr_fromfpga : natural range 0 to BITS - 1 := 0;
	signal actual_bit_ctr_tofpga : natural range 0 to BITS - 1 := 0;

	-- parallel input buffer (FPGA -> IC)
	signal parallel_fromfpga, next_parallel_fromfpga
		: std_logic_vector(BITS - 1 downto 0) := (others => '0');

	-- serial output buffer (FPGA -> IC)
	signal serial_fromfpga : std_logic := SERIAL_DATA_INACTIVE;

	-- parallel output buffer (IC -> FPGA)
	signal parallel_tofpga, next_parallel_tofpga
		: std_logic_vector(BITS - 1 downto 0) := (others => '0');

begin
	-----------------------------------------------------------------------
	-- generate serial clocks
	-----------------------------------------------------------------------
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
		-- inactive '1' and trigger on rising edge
		out_clk <= serial_clk
			when serial_fromfpga_state = Transmit or in_enable_tofpga = '1'
			else '1';
	else generate
		-- inactive '0' and trigger on falling edge
		out_clk <= not serial_clk
			when serial_fromfpga_state = Transmit or in_enable_tofpga = '1'
			else '0';
	end generate;
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	-- get bit counter with correct ordering
	-----------------------------------------------------------------------
	gen_ctr_1 : if LOWBIT_FIRST = '1' generate
		actual_bit_ctr_fromfpga <= bit_ctr_fromfpga;
		actual_bit_ctr_tofpga <= bit_ctr_tofpga;
	else generate
		actual_bit_ctr_fromfpga <= BITS - bit_ctr_fromfpga - 1;
		actual_bit_ctr_tofpga <= BITS - bit_ctr_tofpga - 1;
	end generate;
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	-- output parallel data to register (FPGA -> IC)
	-----------------------------------------------------------------------
	gen_from_fpga_ff : if FROM_FPGA_FALLING_EDGE = '1' generate
		fpga_to_ic_ff : process(serial_clk_data, in_reset) begin
			if in_reset = '1' then
				-- state register
				serial_fromfpga_state <= Ready;

				-- data
				parallel_fromfpga <= (others => '0');

				-- counter register
				bit_ctr_fromfpga <= 0;

			elsif falling_edge(serial_clk_data) then
				-- state register
				serial_fromfpga_state <= next_serial_fromfpga_state;

				-- data
				parallel_fromfpga <= next_parallel_fromfpga;

				-- counter register
				bit_ctr_fromfpga <= next_bit_ctr_fromfpga;
			end if;
		end process;
	else generate
		fpga_to_ic_ff : process(serial_clk_data, in_reset) begin
			if in_reset = '1' then
				-- state register
				serial_fromfpga_state <= Ready;

				-- data
				parallel_fromfpga <= (others => '0');

				-- counter register
				bit_ctr_fromfpga <= 0;

			elsif rising_edge(serial_clk_data) then
				-- state register
				serial_fromfpga_state <= next_serial_fromfpga_state;

				-- data
				parallel_fromfpga <= next_parallel_fromfpga;

				-- counter register
				bit_ctr_fromfpga <= next_bit_ctr_fromfpga;
			end if;
		end process;
	end generate;


	proc_input : process(in_enable_fromfpga, serial_fromfpga_state,
		bit_ctr_fromfpga, in_parallel, parallel_fromfpga)
	begin
		-- defaults
		next_serial_fromfpga_state <= serial_fromfpga_state;
		next_parallel_fromfpga <= parallel_fromfpga;
		next_bit_ctr_fromfpga <= bit_ctr_fromfpga;
		out_next_word_fromfpga <= '0';

		if in_enable_fromfpga = '1' then
			next_parallel_fromfpga <= in_parallel;
		end if;

		-- state machine
		case serial_fromfpga_state is
			-- wait for enable signal
			when Ready =>
				next_bit_ctr_fromfpga <= 0;
				if in_enable_fromfpga = '1' then
					next_serial_fromfpga_state <= Transmit;
				end if;

			-- serialise parallel data
			when Transmit =>
				-- end of word?
				if bit_ctr_fromfpga = BITS - 1 then
					out_next_word_fromfpga <= '1';
					next_bit_ctr_fromfpga <= 0;
				else
					-- next bit of the word
					next_bit_ctr_fromfpga <= bit_ctr_fromfpga + 1;
				end if;

				-- enable signal not active anymore?
				if in_enable_fromfpga = '0' then
					next_serial_fromfpga_state <= Ready;
				end if;

			-- default state
			when others =>
				next_serial_fromfpga_state <= Ready;
		end case;
	end process;


	--
	-- buffer output with the chosen bit ordering (FPGA -> IC)
	--
	serial_fromfpga <= parallel_fromfpga(actual_bit_ctr_fromfpga);


	--
	-- output serial data (FPGA -> IC)
	--
	out_serial <= serial_fromfpga
		when serial_fromfpga_state = Transmit
		else SERIAL_DATA_INACTIVE;
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	-- buffer serial input (IC -> FPGA)
	-----------------------------------------------------------------------
	gen_to_fpga_ff : if TO_FPGA_FALLING_EDGE = '1' generate
		ic_to_fpga_ff : process(serial_clk_data, in_reset) begin
			if in_reset = '1' then
				-- data
				parallel_tofpga <= (others => '0');

				-- counter register
				bit_ctr_tofpga <= 0;

			elsif falling_edge(serial_clk_data) then
				-- data
				parallel_tofpga <= next_parallel_tofpga;

				-- counter register
				bit_ctr_tofpga <= next_bit_ctr_tofpga;
			end if;
		end process;
	else generate
		ic_to_fpga_ff : process(serial_clk_data, in_reset) begin
			if in_reset = '1' then
				-- data
				parallel_tofpga <= (others => '0');

				-- counter register
				bit_ctr_tofpga <= 0;

			elsif rising_edge(serial_clk_data) then
				-- data
				parallel_tofpga <= next_parallel_tofpga;

				-- counter register
				bit_ctr_tofpga <= next_bit_ctr_tofpga;
			end if;
		end process;
	end generate;


	proc_in : process(in_enable_tofpga, in_serial, parallel_tofpga, bit_ctr_tofpga)
	begin
		-- defaults
		next_parallel_tofpga <= parallel_tofpga;
		next_bit_ctr_tofpga <= bit_ctr_tofpga;
		out_next_word_tofpga <= '0';

		if in_enable_tofpga = '1' then
			next_parallel_tofpga(actual_bit_ctr_tofpga) <= in_serial;

			-- end of word?
			if bit_ctr_tofpga = BITS - 1 then
				out_next_word_tofpga <= '1';
				next_bit_ctr_tofpga <= 0;
			else
				next_bit_ctr_tofpga <= bit_ctr_tofpga + 1;
			end if;
		else
			next_bit_ctr_tofpga <= 0;
		end if;
	end process;


	--
	-- output read parallel data (IC -> FPGA)
	--
	out_parallel <= parallel_tofpga;
	-----------------------------------------------------------------------

end architecture;
