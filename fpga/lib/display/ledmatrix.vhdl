--
-- led matrix
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 19-oct-2025, nov-2025
-- @license see 'LICENSE' file
--
-- references:
--   - [hw] https://www.analog.com/en/products/max7219.html
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity ledmatrix is
	generic(
		constant MAIN_CLK     : natural   := 50_000_000;
		constant BUS_BITS     : natural   := 16;

		constant NUM_SEGS     : natural   := 8;
		constant LEDS_PER_SEG : natural   := 8;

		-- transpose pixel matrix (or reverse segment order)
		constant TRANSPOSE    : std_logic := '0'
	);

	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- input new value
		in_update : in std_logic;
		in_digits : in std_logic_vector(4*NUM_SEGS - 1 downto 0);

		-- serial bus interface
		in_bus_ready, in_bus_next_word : in std_logic;
		out_bus_enable, out_seg_enable : out std_logic;
		out_bus_data : out std_logic_vector(BUS_BITS - 1 downto 0)
	);
end entity;


architecture ledmatrix_impl of ledmatrix is

	-- memory
	signal mem, next_mem : std_logic_vector(4*NUM_SEGS - 1 downto 0);
	signal update, next_update : std_logic;

	-- seven segment decoder module
	signal digit : std_logic_vector(3 downto 0);
	signal leds : std_logic_vector(LEDS_PER_SEG - 1 downto 0);

	-- wait timer
	constant WAIT_RESET  : natural := MAIN_CLK / 1000 * 100;  -- 100 ms
	constant WAIT_UPDATE : natural := MAIN_CLK / 1000 * 50;   -- 50 ms, 20 Hz
	constant WAIT_INIT   : natural := MAIN_CLK / 1000_000;    -- 1 mus

	signal wait_ctr, wait_ctr_max : natural range 0 to WAIT_RESET := 0;

	-- --------------------------------------------------------------------
	-- init data
	-- --------------------------------------------------------------------
	-- basic command types, [hw, p. 7]
	constant CMD_DECODE : std_logic_vector(7 downto 0) := "00001001";
	constant CMD_BRIGHT : std_logic_vector(7 downto 0) := "00001010";
	constant CMD_LIMIT  : std_logic_vector(7 downto 0) := "00001011";
	constant CMD_POWER  : std_logic_vector(7 downto 0) := "00001100";
	constant CMD_TEST   : std_logic_vector(7 downto 0) := "00001111";

	-- init sequence, [hw, pp. 7 - 10]
	constant INIT_WORDS : natural := 5;
	type t_init_words is array(0 to INIT_WORDS - 1)
		of std_logic_vector(BUS_BITS - 1 downto 0);
	constant init_cmds : t_init_words := (
		std_logic_vector'(CMD_POWER  & "0000" & "0001"),
		std_logic_vector'(CMD_DECODE & "0000" & "0000"),
		std_logic_vector'(CMD_BRIGHT & "0000" & "1111"),
		std_logic_vector'(CMD_LIMIT  &  nat_to_logvec(NUM_SEGS - 1, 8)),
		std_logic_vector'(CMD_TEST   & "0000" & "0000")
	);
	signal init_ctr, next_init_ctr : natural range 0 to INIT_WORDS := 0;

	signal seg_ctr, next_seg_ctr : natural range 1 to NUM_SEGS := 1;
	-- --------------------------------------------------------------------

	-- serial bus interface
	signal last_byte_finished, bus_enable, seg_enable : std_logic := '0';
	signal bus_cycle : std_logic;
	signal bus_data : std_logic_vector(BUS_BITS - 1 downto 0);

	-- state machine
	type t_state is (
		Reset,
		EnableInit, WriteInit, NextInit,
		WaitUpdate, WaitUpdate2,
		EnableData, WriteData, NextData
	);

	signal state, next_state : t_state := Reset;


begin

	-- --------------------------------------------------------------------
	-- memory
	-- --------------------------------------------------------------------
	mem_ff : process(in_clk, in_rst) begin
		if in_rst = '1' then
			mem <= (others => '0');
			update <= '1';
		elsif rising_edge(in_clk) then
			mem <= next_mem;
			update <= next_update;
		end if;
	end process;


	mem_proc : process(mem, update, in_update, in_digits) begin
		next_mem <= mem;
		next_update <= update;

		-- get input data
		if in_update = '1' then
			next_update <= '1';
			next_mem <= in_digits;
		end if;
	end process;
	-- --------------------------------------------------------------------


	-- --------------------------------------------------------------------
	-- seven segment decoder module
	-- --------------------------------------------------------------------
	sevenseg_mod : entity work.sevenseg
		generic map(ZERO_IS_ON => '0', INVERSE_NUMBERING => '0', ROTATED => not TRANSPOSE)
		port map(in_digit => digit, out_leds => leds(6 downto 0));

	gen_seg_if : if TRANSPOSE = '0' generate
		digit <= mem((NUM_SEGS - seg_ctr)*4 to (NUM_SEGS - seg_ctr)*4 + 4);
	end generate;
	gen_seg_else : if TRANSPOSE = '1' generate
		digit <= mem((seg_ctr - 1)*4 to (seg_ctr - 1)*4 + 4);
	end generate;
	-- --------------------------------------------------------------------


	-- --------------------------------------------------------------------
	-- serial bus interface and outputs
	-- --------------------------------------------------------------------
	bus_cycle <= in_bus_next_word and not last_byte_finished;

	out_seg_enable <= seg_enable;
	out_bus_enable <= bus_enable;
	out_bus_data <= bus_data;
	-- --------------------------------------------------------------------


	-- --------------------------------------------------------------------
	-- state machine
	-- --------------------------------------------------------------------
	state_ff : process(in_clk, in_rst) begin
		if in_rst = '1' then
			state <= Reset;
			last_byte_finished <= '0';

			init_ctr <= 0;
			seg_ctr <= 1;
			wait_ctr <= 0;

		elsif rising_edge(in_clk) then
			state <= next_state;
			last_byte_finished <= in_bus_next_word;

			init_ctr <= next_init_ctr;
			seg_ctr <= next_seg_ctr;

			if wait_ctr = wait_ctr_max then
				wait_ctr <= 0;
			else
				wait_ctr <= wait_ctr + 1;
			end if;
		end if;
	end process;


	state_comb : process(state, init_ctr, seg_ctr) begin
		next_state <= state;

		next_init_ctr <= init_ctr;
		next_seg_ctr <= seg_ctr;

		wait_ctr_max <= WAIT_RESET;
		seg_enable <= '0';
		bus_enable <= '0';
		bus_data <= (others => '0');

		case state is
			when Reset =>
				wait_ctr_max <= WAIT_RESET;
				if wait_ctr = wait_ctr_max then
					next_state <= WriteInit;
				end if;

			---------------------------------------------------------------
			-- write init commands
			---------------------------------------------------------------
			when EnableInit =>
				seg_enable <= '1';
				wait_ctr_max <= WAIT_INIT;
				if wait_ctr = wait_ctr_max then
					next_state <= WriteInit;
				end if;

			when WriteInit =>
				bus_data <= init_cmds(init_ctr);
				bus_enable <= '1';
				seg_enable <= '1';

				if bus_cycle = '1' then
					next_state <= NextInit;
				end if;

			when NextInit =>
				bus_data <= init_cmds(init_ctr);
				if in_bus_ready = '1' then
					if init_ctr = INIT_WORDS - 1 then
						next_state <= WaitUpdate;
					else
						next_init_ctr <= init_ctr + 1;
						next_state <= WriteInit;
					end if;
				end if;
			---------------------------------------------------------------

			---------------------------------------------------------------
			-- wait for update timer and signal
			---------------------------------------------------------------
			when WaitUpdate =>
				wait_ctr_max <= WAIT_UPDATE;
				if wait_ctr = wait_ctr_max then
					next_state <= WaitUpdate2;
				end if;

			when WaitUpdate2 =>
				if update = '1' then
					next_state <= EnableData;
				end if;
			---------------------------------------------------------------

			---------------------------------------------------------------
			-- write segment byte
			---------------------------------------------------------------
			when EnableData =>
				seg_enable <= '1';
				wait_ctr_max <= WAIT_INIT;
				if wait_ctr = wait_ctr_max then
					next_state <= WriteData;
				end if;

			when WriteData =>
				bus_data <= nat_to_logvec(seg_ctr, BUS_BITS/2) & leds;
				bus_enable <= '1';
				seg_enable <= '1';

				if bus_cycle = '1' then
					next_state <= NextData;
				end if;

			when NextData =>
				bus_data <= nat_to_logvec(seg_ctr, BUS_BITS/2) & leds;
				if in_bus_ready = '1' then
					if seg_ctr = NUM_SEGS then
						-- at last segment
						next_seg_ctr <= 1;
						next_state <= WaitUpdate;
					else
						next_seg_ctr <= seg_ctr + 1;
						next_state <= WriteData;
					end if;
				end if;
			---------------------------------------------------------------

			when others =>
				next_state <= Reset;
		end case;
	end process;
	-- --------------------------------------------------------------------

end architecture;
