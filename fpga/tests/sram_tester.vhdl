--
-- sram tester
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 13 March 2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity sram_tester is
	-- constants
	generic
	(
		constant ADDR_WIDTH : natural := 18;
		constant DATA_WIDTH : natural := 16;

		constant MAIN_CLK_HZ : natural := 50_000_000;
		constant MEM_CLK_HZ : natural := 1_000_000;
		constant USE_SLOW_CLK : std_logic := '0'
	);

-- interface
	port
	(
		-- clock
		clock_50_b7a : in std_logic;

		-- sram
		sram_a : out std_logic_vector(ADDR_WIDTH-1 downto 0);
		sram_d : inout std_logic_vector(DATA_WIDTH-1 downto 0);
		sram_ub_n : out std_logic;  -- upper byte enable
		sram_lb_n : out std_logic;  -- lower byte enable
		sram_ce_n : out std_logic;  -- chip enable
		sram_oe_n : out std_logic;  -- output enable
		sram_we_n : out std_logic;  -- write enable

		-- switches
		key : in std_logic_vector(0 downto 0);
		sw : in std_logic_vector(9 downto 0);

		-- leds
		ledg : out std_logic_vector(7 downto 0);
		ledr : out std_logic_vector(9 downto 0);

		-- output segment display
		hex0 : out std_logic_vector(6 downto 0);
		hex1 : out std_logic_vector(6 downto 0);
		hex2 : out std_logic_vector(6 downto 0);
		hex3 : out std_logic_vector(6 downto 0)
	);
end entity;



architecture sram_tester_impl of sram_tester is
	-- states
	type t_state is (
		BeginWriting, Writing,
		BeginReading, Reading, ReadNext,
		Manual
	);
	signal state, state_next : t_state := BeginWriting;

	signal mem_clk : std_logic := '0';

	signal addr : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal addr_from_ctr : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal in_data : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal out_data : std_logic_vector(DATA_WIDTH-1 downto 0);

	signal reset : std_logic := '0';
	signal start_memop, select_write : std_logic := '0';

	-- signal to select next address
	signal sram_ready : std_logic;
	signal to_next_addr : std_logic;
	signal reset_addrctr : std_logic := '0';

	-- enter address manually using the switches
	signal manual_addr : std_logic := '0';

	signal at_first_addr, at_last_addr : std_logic := '0';
	signal error, error_next : std_logic := '0';

begin
	---------------------------------------------------------------------------
	-- input and output
	---------------------------------------------------------------------------
	reset <= not key(0);

	-- chip and byte enable signals
	sram_ub_n <= '0';
	sram_lb_n <= '0';
	sram_ce_n <= '0';

	-- select address using switches
	addr(ADDR_WIDTH-1 downto 10) <= (others => '0') when manual_addr = '1'
		else addr_from_ctr(ADDR_WIDTH-1 downto 10);
	addr(9 downto 0) <= sw when manual_addr = '1'
		else addr_from_ctr(9 downto 0);

	-- leds
	ledg(7 downto 5) <= (others => error);
	ledg(0) <= reset;
	ledg(1) <= select_write;
	ledg(2) <= manual_addr;
	ledg(3) <= at_first_addr;
	ledg(4) <= at_last_addr;
	ledr <= addr(9 downto 0);

	-- write lower bits of address as test data
	in_data <= addr(DATA_WIDTH-1 downto 0);
	--in_data <= (others => '0');
	---------------------------------------------------------------------------


	-- address counter
	addr_ctr : entity work.counter
		generic map(BITS => ADDR_WIDTH)
		port map
		(
			in_clk => to_next_addr, in_reset => reset or reset_addrctr,
			out_counter => addr_from_ctr,
			out_at_start => at_first_addr, out_at_end => at_last_addr
		);


	-- sram controller
	sram_ctrl : entity work.sram_ctrl
		generic map
		(
			ADDR_WIDTH => ADDR_WIDTH, DATA_WIDTH => DATA_WIDTH,
			ENABLES_ACTIVE_HIGH => '0'
		)
		port map
		(
			-- clock and reset
			in_clk => mem_clk, in_reset => reset,
			-- input/output data and address
			in_addr => addr, in_data => in_data, out_data => out_data,
			in_start => start_memop, in_write => select_write,
			out_ready => sram_ready,
			-- sram interface
			out_sram_readenable => sram_oe_n, out_sram_writeenable => sram_we_n,
			out_sram_addr => sram_a, inout_sram_data => sram_d
		);


	-- output data at current address
	sevenseg_data0 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => out_data(3 downto 0), out_leds => hex0);
	sevenseg_data1 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => out_data(7 downto 4), out_leds => hex1);
	sevenseg_data2 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => out_data(11 downto 8), out_leds => hex2);
	sevenseg_data3 : entity work.sevenseg
		generic map(zero_is_on => '1', inverse_numbering => '1')
		port map(in_digit => out_data(15 downto 12), out_leds => hex3);


	gen_slow_clk : if USE_SLOW_CLK = '1'
	generate
		-- generate a slow clock
		clkgen : entity work.clkgen
			generic map(MAIN_HZ => MAIN_CLK_HZ, CLK_HZ => MEM_CLK_HZ)
			port map(in_clk => clock_50_b7a, in_reset => reset, out_clk => mem_clk);
	end generate;

	gen_fast_clk : if USE_SLOW_CLK = '0'
	generate
		-- use the main clock
		mem_clk <= clock_50_b7a;
	end generate;


	---------------------------------------------------------------------------
	-- state machine flip-flops
	---------------------------------------------------------------------------
	proc_state_ff : process(clock_50_b7a) is
	begin
		-- clock
		if rising_edge(clock_50_b7a) then
			if reset = '1' then
				-- synchronous reset
				state <= BeginWriting;
				error <= '0';
			else
				-- advance states
				state <= state_next;
				error <= error_next;
			end if;
		end if;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- combinatoric part of the state machine for waveform generation
	---------------------------------------------------------------------------
	proc_state_comb : process(state,
		at_first_addr, at_last_addr,
		out_data, addr, error, sram_ready) is
	begin
		-- save registers into next cycle
		state_next <= state;
		error_next <= error;

		-- default values
		manual_addr <= '0';
		select_write <= '0';
		reset_addrctr <= '0';
		start_memop <= '0';
		to_next_addr <= '0';

		case state is
			when BeginWriting =>
				reset_addrctr <= '1';

				if at_first_addr = '1' then
					state_next <= Writing;
				end if;

			-- write values to memory
			when Writing =>
				error_next <= '0';
				select_write <= '1';
				start_memop <= '1';

				if sram_ready = '1' then
					to_next_addr <= '1';
					-- addresses wrapped around?
					if at_first_addr = '1' then
						state_next <= BeginReading;
					end if;
				end if;

			-- read at current address
			when BeginReading =>
				start_memop <= '1';

				if sram_ready = '1' then
					state_next <= Reading;
				end if;

			-- read back the values and test if they are correct
			when Reading =>
				start_memop <= '1';

				if sram_ready = '1' then
					if out_data /= addr(DATA_WIDTH-1 downto 0) then
						state_next <= Manual;
						error_next <= '1';
					else
						state_next <= ReadNext;
					end if;

					if at_last_addr = '1' then
						state_next <= Manual;
					end if;
				end if;

			-- increament address
			when ReadNext =>
				to_next_addr <= '1';
				state_next <= BeginReading;

			-- manual address entry
			when Manual =>
				start_memop <= '1';
				manual_addr <= '1';  -- comment out to see error data and address

		end case;
	end process;
	---------------------------------------------------------------------------

end architecture;
