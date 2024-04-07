--
-- video output configuration via 2-wire serial bus
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 6-apr-2024
-- @license see 'LICENSE' file
--
-- references for video chip:
--   - [hw] https://www.analog.com/media/en/technical-documentation/user-guides/adv7513_hardware_user_guide.pdf
--   - [sw] https://www.analog.com/media/en/technical-documentation/user-guides/adv7513_programming_guide.pdf
-- reference for serial bus usage:
--   - https://www.digikey.com/eewiki/pages/viewpage.action?pageId=10125324
--
-- note: serial data and clock signal need to be declared 3-state (high-Z for idle state)
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;


entity video_cfg is
	generic(
		-- clock
		constant MAIN_CLK : natural := 50_000_000;

		-- word length and address of the serial bus
		constant BUS_NUM_ADDRBITS : natural := 8;
		constant BUS_NUM_DATABITS : natural := 8;
		constant BUS_WRITEADDR : std_logic_vector(BUS_NUM_ADDRBITS-1 downto 0) := x"10";
		constant BUS_READADDR : std_logic_vector(BUS_NUM_ADDRBITS-1 downto 0) := x"11"
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- serial bus interface
		in_bus_busy, in_bus_error : in std_logic;
		in_bus_data : in std_logic_vector(BUS_NUM_DATABITS-1 downto 0);
		out_bus_enable : out std_logic;
		out_bus_addr : out std_logic_vector(BUS_NUM_ADDRBITS-1 downto 0);
		out_bus_data : out std_logic_vector(BUS_NUM_DATABITS-1 downto 0);

		-- values of status register
		out_status : out std_logic_vector(BUS_NUM_DATABITS-1 downto 0)
	);
end entity;



architecture video_cfg_impl of video_cfg is
	-- states
	type t_state is ( Wait_Reset,
		Set_Registers_Addr, Set_Registers_Data, Set_Registers_Next,
		Read_Reg_Write_Addr, Read_Reg, Read_Reg_Data,
		Idle);
	signal state, next_state : t_state := Wait_Reset;

	-- serial bus busy signal
	signal bus_last_busy, bus_cycle : std_logic := '0';

	-- reset delay and counter for busy wait
	constant const_wait_reset : natural := MAIN_CLK/1000*200;  -- 200 ms [hw, p. 36]
	signal wait_counter, wait_counter_max : natural range 0 to const_wait_reset := 0;

	-- status register
	signal status_reg, next_status_reg : std_logic_vector(BUS_NUM_DATABITS-1 downto 0) := (others => '0');

	-- register init sequence
	type t_init_arr is array(0 to 16*2 - 1) of std_logic_vector(BUS_NUM_DATABITS-1 downto 0);
	constant init_arr : t_init_arr := (
	-- reg,   val
		x"41", x"00",          -- power on, [sw, p. 149]

		-- constants, [sw, p. 14, p. 25]
		x"98", x"03",
		x"9a", x"e0",
		x"9c", x"30",
		x"9d", x"01",
		x"a2", x"a4",
		x"a3", x"a4",
		x"e0", x"d0",
		x"f9", x"00",

		x"15", b"00000000",  -- input format, [sw, p. 34, p. 141]
		x"16", b"00110100",  -- in/out formats, [sw, p. 34, p. 142]
		x"17", b"00000010",  -- aspect, [sw, p. 34, p. 143]
		x"18", b"00000000",  -- colour space converter, [sw, p. 144]
		x"55", b"00000000",  -- output format
		x"a1", b"00000010",  -- monitor sense
		x"af", b"00000010"   -- mode
	);

	signal init_cycle, next_init_cycle : natural range 0 to init_arr'length := 0;


begin

	-- output status register
	out_status <= status_reg;


	-- rising edge of serial bus busy signal
	bus_cycle <= in_bus_busy and (not bus_last_busy);


	--
	-- state flip-flops
	--
	proc_ff : process(in_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			state <= Wait_Reset;

			-- command counter
			init_cycle <= 0;

			-- status register
			status_reg <= (others => '0');

			-- timer register
			wait_counter <= 0;

			bus_last_busy <= '0';

		-- clock
		elsif rising_edge(in_clk) then
			-- state register
			state <= next_state;

			-- command counter
			init_cycle <= next_init_cycle;

			-- status register
			status_reg <= next_status_reg;

			-- timer register
			if wait_counter = wait_counter_max then
				-- reset timer counter
				wait_counter <= 0;
			else
				-- next timer counter
				wait_counter <= wait_counter + 1;
			end if;

			bus_last_busy <= in_bus_busy;
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(
		state, wait_counter, wait_counter_max,
		in_bus_busy, in_bus_error, in_bus_data,
		status_reg, bus_cycle, init_cycle)
	begin
		-- defaults
		next_state <= state;
		next_init_cycle <= init_cycle;
		next_status_reg <= status_reg;
		wait_counter_max <= 0;

		out_bus_enable <= '0';
		out_bus_addr <= BUS_READADDR;
		out_bus_data <= (others => '0');


		-- fsm
		case state is

			-- reset, [hw, p. 36]
			when Wait_Reset =>
				wait_counter_max <= const_wait_reset;
				if wait_counter = wait_counter_max then
					next_state <= Set_Registers_Addr;
				end if;


			----------------------------------------------------------------------
			-- write to registers, [sw, p. 14ff]
			----------------------------------------------------------------------
			when Set_Registers_Addr =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register address
				out_bus_data <= init_arr(init_cycle);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= Set_Registers_Data;
				end if;

			when Set_Registers_Data =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register value
				out_bus_data <= init_arr(init_cycle + 1);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= Set_Registers_Next;
				end if;

			when Set_Registers_Next =>
				if in_bus_busy = '0' then
					if init_cycle + 2 = init_arr'length then
						-- at end of command list
						next_state <= Read_Reg_Write_Addr;
						next_init_cycle <= 0;
					else
						-- next command
						next_init_cycle <= init_cycle + 2;
						next_state <= Set_Registers_Addr;
					end if;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- read register, [hw, p. 38; sw, p. 17]
			----------------------------------------------------------------------
			when Read_Reg_Write_Addr =>
				out_bus_addr <= BUS_WRITEADDR;
				out_bus_data <= x"42";  -- register address, [sw, p. 150]
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= Read_Reg;
				end if;

			when Read_Reg =>
				out_bus_addr <= BUS_READADDR;
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					out_bus_enable <= '0';
					next_state <= Read_Reg_Data;
				end if;

			when Read_Reg_Data =>
				if in_bus_busy = '0' then
					--next_status_reg <= (others => '1');
					next_status_reg <= in_bus_data;
					next_state <= Idle;
				end if;
			----------------------------------------------------------------------


			when Idle =>


			when others =>
				next_state <= Wait_Reset;
		end case;
	end process;

end architecture;
