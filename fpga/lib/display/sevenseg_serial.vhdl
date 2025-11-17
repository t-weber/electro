--
-- serial seven segment display
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 18-oct-2025, 16-nov-2025
-- @license see 'LICENSE' file
--
-- references:
--   - https://www.puntoflotante.net/TM1637-7-SEGMENT-DISPLAY-FOR-MICROCONTROLLER.htm
--

library ieee;
use ieee.std_logic_1164.all;


entity sevenseg_serial is
	generic(
		constant MAIN_CLK : natural := 50_000_000;
		constant BUS_BITS : natural := 8;
		constant NUM_SEGS : natural := 6;
	);

	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- input new value
		in_update : in std_logic;
		in_digits : in std_logic_vector(4*NUM_SEGS - 1 downto 0);

		-- serial bus interface
		in_bus_ready, in_bus_next_word : in std_logic;
		out_bus_enable : out std_logic;
		out_bus_data : out std_logic_vector(BUS_BITS - 1 downto 0);
	);
end entity;


architecture sevenseg_serial_impl of sevenseg_serial is

	-- memory
	signal mem, next_mem : std_logic_vector(4*NUM_SEGS - 1 downto 0);
	signal update, next_update : std_logic;

	-- seven segment decoder module
	signal digit : std_logic_vector(3 downto 0);
	signal leds : std_logic_vector(6 downto 0);

	-- wait timer
	constant WAIT_RESET  : natural := MAIN_CLK / 1000 * 100;  -- 100 ms
	constant WAIT_UPDATE : natural := MAIN_CLK / 1000 * 100;  -- 100 ms, 10 Hz

	signal wait_ctr, wait_ctr_max : natural range 0 to WAIT_UPDATE := 0;

	-- --------------------------------------------------------------------
	-- init data
	-- --------------------------------------------------------------------
	-- basic command types
	constant CMD_DATA : std_logic_vector(3 downto 0) := "0100";
	constant CMD_DISP : std_logic_vector(3 downto 0) := "1000";
	constant CMD_ADDR : std_logic_vector(3 downto 0) := "1100";

	-- constant (1) or incrementing (0) address
	constant CONST_ADDR : std_logic_vector(0 downto 0) := "1";

	-- led brightness
	constant BRIGHTNESS : std_logic_vector(3 downto 0) := x"f";

	-- init sequence
	constant INIT_BYTES : natural := 1;
	type t_init_bytes is array(0 to INIT_BYTES - 1) of std_logic_vector(2*BUS_BITS - 1 downto 0);
	constant init_cmds : t_init_bytes := (
		CMD_DISP, BRIGHTNESS
	);
	signal init_ctr, next_init_ctr : natural range 0 to INIT_BYTES := 0;

	-- data transmission sequence
	constant DATA_BYTES : natural := 2;
	type t_data_bytes is array(0 to DATA_BYTES - 1) of std_logic_vector(2*BUS_BITS - 1 downto 0);
	constant data_cmds : t_data_bytes := (
		CMD_DATA & '0' & not CONST_ADDR & "00",
		CMD_ADDR & "0000"  -- start address 0
	);
	signal data_ctr, next_data_ctr : natural range 0 to DATA_BYTES := 0;

	signal seg_ctr, next_seg_ctr : natural range 0 to NUM_SEGS - 1 := 0;
	-- --------------------------------------------------------------------

	-- serial bus interface
	signal last_byte_finished, bus_enable : std_logic := '0';
	signal bus_cycle : std_logic;
	signal bus_data : std_logic_vector(BUS_BITS - 1 downto 0);

	-- state machine
	type t_state is (
		Reset,
		WriteInit, NextInit,
		WaitUpdate, WaitUpdate2,
		WriteDataInit, NextDataInit,
		WriteData, NextData
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
		generic map(ZERO_IS_ON => '0', INVERSE_NUMBERING => '1', ROTATED => '1')
		port map(in_digit => digit, out_leds => leds);

	digit <= mem(seg_ctr*4 to seg_ctr*4 + 4);
	-- --------------------------------------------------------------------


	-- --------------------------------------------------------------------
	-- serial bus interface and outputs
	-- --------------------------------------------------------------------
	bus_cycle <= in_bus_next_word and not last_byte_finished;

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
			data_ctr <= 0;
			seg_ctr <= 0;
			wait_ctr <= 0;

		elsif rising_edge(in_clk) then
			state <= next_state;
			last_byte_finished <= in_bus_next_word;

			init_ctr <= next_init_ctr;
			data_ctr <= next_data_ctr;
			seg_ctr <= next_seg_ctr;

			if wait_ctr = wait_ctr_max then
				wait_ctr <= 0;
			else
				wait_ctr <= wait_ctr + 1;
			end if;
		end if;
	end process;


	state_comb : process(state, init_ctr, data_ctr, seg_ctr) begin
		next_state <= state;

		next_init_ctr <= init_ctr;
		next_data_ctr <= data_ctr;
		next_seg_ctr <= seg_ctr;

		wait_ctr_max <= WAIT_RESET;
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
			when WriteInit =>
				bus_data <= init_cmds(init_ctr);
				bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= NextInit;
				end if;

			when NextInit =>
				if init_ctr + 1 = INIT_BYTES then
					if in_bus_ready = '1' then
						next_state <= WaitUpdate;
					end if;
				else
					bus_data <= init_cmds(init_ctr);

					-- send stop command
					if in_bus_ready = '1' then
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
					next_state <= WriteDataInit;
				end if;
			---------------------------------------------------------------

			---------------------------------------------------------------
			-- write data transfer commands
			---------------------------------------------------------------
			when WriteDataInit =>
				bus_data <= data_cmds(init_ctr);
				bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= NextDataInit;
				end if;

			when NextDataInit =>
				if data_ctr + 1 = DATA_BYTES then
					bus_enable <= '1';
					next_state <= WriteData;
				else
					bus_data <= data_cmds(init_ctr);

					-- send stop command
					if in_bus_ready = '1' then
						next_data_ctr <= data_ctr + 1;
						next_state <= WriteDataInit;
					end if;
				end if;
			---------------------------------------------------------------

			---------------------------------------------------------------
			-- write segment byte
			---------------------------------------------------------------
			when WriteData =>
				bus_data <= '0' & leds;
				bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= NextData;
				end if;

			when NextData =>
				bus_data <= '0' & leds;
				if seg_ctr = NUM_SEGS - 1 then
					-- at last segmentt
					if in_bus_ready = '1' then
						-- all finished
						next_seg_ctr <= 0;
						next_state <= WaitUpdate;
					end if;
				else
					next_seg_ctr <= seg_ctr + 1;
					next_state <= WriteData;
					bus_enable <= '1';
				end if;
			---------------------------------------------------------------

			when others =>
				next_state <= Reset;
		end case;
	end process;
	-- --------------------------------------------------------------------

end architecture;
