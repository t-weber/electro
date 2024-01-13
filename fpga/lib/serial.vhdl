--
-- serial controller: serialises parallel data
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

		-- serial output data
		out_clk, out_ready : out std_logic;
		out_serial, out_next_word : out std_logic;

		-- parallel input data
		in_parallel : in std_logic_vector(BITS-1 downto 0);
		in_enable : in std_logic
	);
end entity;



architecture serial_impl of serial is
	-- states and next state logic
	type t_serial_state is ( Ready, Transmit );
	signal serial_state, next_serial_state : t_serial_state := Ready;
	signal parallel_data, next_parallel_data : std_logic_vector(BITS-1 downto 0);

	-- serial clock
	signal serial_clk : std_logic := SERIAL_CLK_INACTIVE;

	-- bit counter
	signal bit_ctr, next_bit_ctr : natural range 0 to BITS-1 := 0;

	-- serial output buffer
	signal out_serial_buf : std_logic := SERIAL_DATA_INACTIVE;

begin
	--
	-- generate serial clock
	--
	proc_clk : process(in_clk, in_reset)
		constant clk_ctr_max : natural := MAIN_HZ / SERIAL_HZ / 2 - 1;
		variable clk_ctr : natural range 0 to clk_ctr_max := 0;
	begin
		-- reset
		if in_reset = '1' then
			clk_ctr := 0;
			serial_clk <= SERIAL_CLK_INACTIVE;

		-- clock
		elsif rising_edge(in_clk) then
			if clk_ctr = clk_ctr_max then
				serial_clk <= not serial_clk;
				clk_ctr := 0;
			else
				clk_ctr := clk_ctr + 1;
			end if;
		end if;
	end process;


	-- output serial clock
	out_clk <= serial_clk when serial_state = Transmit else SERIAL_CLK_INACTIVE;


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

		-- clock
		--elsif falling_edge(in_clk) then
		elsif rising_edge(in_clk) then
			-- parallel data register
			parallel_data <= next_parallel_data;
		end if;
	end process;


	--
	-- buffer input parallel data
	--
	proc_input : process(in_enable, in_parallel, parallel_data)
	begin
		next_parallel_data <= parallel_data;

		if in_enable = '1' then
			next_parallel_data <= in_parallel;
		end if;
	end process;


	--
	-- generate output with the chosen bit ordering
	--
	gen_outp_1 : if LOWBIT_FIRST = '1' generate
		out_serial_buf <= parallel_data(bit_ctr);
	end generate;
	gen_outp_0 : if LOWBIT_FIRST = '0' generate
		out_serial_buf <= parallel_data(BITS - bit_ctr - 1);
	end generate;


	--
	-- state combinatorics
	--
	proc_comb : process(in_enable, serial_state, bit_ctr, parallel_data, out_serial_buf)
	begin
		-- defaults
		next_serial_state <= serial_state;
		next_bit_ctr <= bit_ctr;

		out_next_word <= '0';
		out_ready <= '0';
		out_serial <= SERIAL_DATA_INACTIVE;

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
				-- output current bit
					out_serial <= out_serial_buf;

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
