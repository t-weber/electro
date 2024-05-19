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
		in_bus_ready, in_bus_error : in std_logic;
		in_bus_data : in std_logic_vector(BUS_NUM_DATABITS-1 downto 0);
		in_bus_byte_finished : in std_logic;

		-- video status interrupt
		in_int : in std_logic;

		out_bus_enable : out std_logic;
		out_bus_addr : out std_logic_vector(BUS_NUM_ADDRBITS-1 downto 0);
		out_bus_data : out std_logic_vector(BUS_NUM_DATABITS-1 downto 0);

		-- is a monitor connected and the video output active?
		out_status : out std_logic_vector(BUS_NUM_DATABITS-1 downto 0);
		out_active : out std_logic
	);
end entity;



architecture video_cfg_impl of video_cfg is
	-- states
	type t_state is ( Wait_Reset, CheckStatus,
		SetupInt_SetAddr, SetupInt_SetData, SetupInt_Next,
		ReadStatus_SetAddr, ReadStatus_SetReg, ReadStatus_GetData,
		PowerUp_SetAddr, PowerUp_SetData, PowerUp_Next,
		PowerDown_SetAddr, PowerDown_SetData, PowerDown_Next,
		Wait_Int, Idle);

	signal state, next_state : t_state := Wait_Reset;

	signal last_bus_byte_finished, bus_cycle : std_logic := '0';

	-- reset delay and counter for busy wait
	constant const_wait_reset : natural := MAIN_CLK/1000*200;  -- 200 ms [hw, p. 36]
	signal wait_counter, wait_counter_max : natural range 0 to const_wait_reset := 0;

	-- status register
	constant CHECK_STATUS_REG : std_logic := '1';
	signal status_reg, next_status_reg : std_logic_vector(BUS_NUM_DATABITS-1 downto 0) := (others => '0');
	signal int_triggered, next_int_triggered : std_logic := '0';

	-- all video outputs on?
	signal is_powered, next_is_powered : std_logic := '0';

	-- power down sequence
	type t_powerdown_arr is array(0 to 2*2 - 1) of std_logic_vector(BUS_NUM_DATABITS-1 downto 0);
	constant powerdown_arr : t_powerdown_arr := (
		-- reg, val
		x"41", "01010000",    -- power off, [sw, p. 149]

		x"96", "11000000"     -- clear interrupts, [sw, p. 130]
	);

	-- power up sequence
	type t_powerup_arr is array(0 to 10*2 - 1) of std_logic_vector(BUS_NUM_DATABITS-1 downto 0);
	constant powerup_arr : t_powerup_arr := (
		-- reg, val
		x"41", "00010000",  -- power on, [sw, p. 149]

		-- set i/o formats
		x"15", "00000000",  -- input format, [sw, p. 34, p. 141]
		x"16", "00110100",  -- in/out formats, [sw, p. 34, p. 142]
		x"17", "00000010",  -- aspect, [sw, p. 34, p. 143]
		x"18", "00000000",  -- colour space converter, [sw, p. 144]
		x"44", "00010001",  -- avi, [sw, p. 150]
		x"55", "00000000",  -- output format, [sw, p. 152]
		x"56", "00101000",  -- aspect, [sw, p. 153]
		x"af", "00000110",  -- mode, [sw, p. 161]

		x"96", "11000000"   -- clear interrupts, [sw, p. 130]
	);

	-- sequence to set up interrupts (and basic constants)
	type t_setupint_arr is array(0 to 12*2 - 1) of std_logic_vector(BUS_NUM_DATABITS-1 downto 0);
	constant setupint_arr : t_setupint_arr := (
		-- reg, val
		x"98", x"03",         -- constants, [sw, p. 14, p. 25]
		x"9a", x"e0",         --
		x"9c", x"30",         --
		x"9d", x"01",         --
		x"a2", x"a4",         --
		x"a3", x"a4",         --
		x"e0", x"d0",         --
		x"f9", x"00",         --

		-- set up interrupt handling
		x"94", "11000000",  -- status interrupts enable, [sw, p. 17, p. 158]
		x"96", "11000000",  -- clear interrupts, [sw, p. 130]
		x"a1", "00000000",  -- monitor sense, [sw, p. 104, p. 160]
		x"d6", "10000000"   -- hotplug detection, [sw, p. 17, p. 164]
	);

	signal PowerDown_cycle, next_PowerDown_cycle : natural range 0 to powerup_arr'length := 0;
	signal powerup_cycle, next_powerup_cycle : natural range 0 to powerup_arr'length := 0;
	signal setupint_cycle, next_setupint_cycle : natural range 0 to setupint_arr'length := 0;

begin

	-- output status registers
	out_active <= status_reg(5) and status_reg(6);
	out_status <= status_reg;


	-- rising edge of serial bus finished signal
	bus_cycle <= in_bus_byte_finished and (not last_bus_byte_finished);
	--bus_cycle <= (not in_bus_byte_finished) and last_bus_byte_finished;


	--
	-- state flip-flops
	--
	proc_ff : process(in_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state register
			state <= Wait_Reset;

			-- command counter
			powerup_cycle <= 0;
			PowerDown_cycle <= 0;
			setupint_cycle <= 0;

			-- status register
			status_reg <= (others => '0');

			-- interrupt signal
			int_triggered <= '0';

			-- all video outputs on?
			is_powered <= '0';

			-- timer register
			wait_counter <= 0;

			last_bus_byte_finished <= '0';

		-- clock
		elsif rising_edge(in_clk) then
			-- state register
			state <= next_state;

			-- command counter
			powerup_cycle <= next_powerup_cycle;
			PowerDown_cycle <= next_PowerDown_cycle;
			setupint_cycle <= next_setupint_cycle;

			-- status register
			status_reg <= next_status_reg;

			-- all video outputs on?
			is_powered <= next_is_powered;

			-- interrupt signal
			int_triggered <= next_int_triggered;

			-- timer register
			if wait_counter = wait_counter_max then
				-- reset timer counter
				wait_counter <= 0;
			else
				-- next timer counter
				wait_counter <= wait_counter + 1;
			end if;

			last_bus_byte_finished <= in_bus_byte_finished;
		end if;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(
		state,
		wait_counter, wait_counter_max,
		in_bus_ready, in_bus_error, in_bus_data,
		bus_cycle, powerup_cycle,
		status_reg, PowerDown_cycle, setupint_cycle,
		in_int, int_triggered, is_powered)
	begin
		-- defaults
		next_state <= state;
		next_powerup_cycle <= powerup_cycle;
		next_PowerDown_cycle <= PowerDown_cycle;
		next_setupint_cycle <= setupint_cycle;
		next_status_reg <= status_reg;
		next_int_triggered <= int_triggered;
		next_is_powered <= is_powered;
		wait_counter_max <= 0;

		out_bus_enable <= '0';
		out_bus_addr <= BUS_READADDR;
		out_bus_data <= (others => '0');


		if in_int = '1' then
			next_int_triggered <= '1';
		end if;


		-- fsm
		case state is

			--
			-- reset delay, [hw, p. 36]
			--
			when Wait_Reset =>
				wait_counter_max <= const_wait_reset;
				if wait_counter = wait_counter_max then
					next_state <= SetUpInt_SetAddr;
				end if;


			--
			-- wait for status interrupt
			--
			when Wait_Int =>
				if int_triggered = '1' then
					-- read status register
					next_state <= ReadStatus_SetAddr;
					next_int_triggered <= '0';
				end if;


			----------------------------------------------------------------------
			-- read status register, [hw, p. 38; sw, p. 17]
			----------------------------------------------------------------------
			when ReadStatus_SetAddr =>
				out_bus_addr <= BUS_WRITEADDR;
				-- status register address, [sw, p. 150]
				out_bus_data <= x"42";
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= ReadStatus_SetReg;
				end if;

			when ReadStatus_SetReg =>
				out_bus_addr <= BUS_READADDR;
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					out_bus_enable <= '0';
					next_state <= ReadStatus_GetData;
				end if;

			when ReadStatus_GetData =>
				out_bus_addr <= BUS_READADDR;

				if in_bus_ready = '1' then
					next_status_reg <= in_bus_data;
					next_state <= CheckStatus;
				end if;

			-- check status register to see if a monitor is present
			when CheckStatus =>
				if is_powered = '0' then
					if status_reg(5) = '1' and status_reg(6) = '1' then
						-- monitor now present -> power on
						next_state <= PowerUp_SetAddr;
					else
						-- monitor still not present
						next_state <= Wait_Int;
					end if;
				else
					if status_reg(5) = '0' or status_reg(6) = '0' then
						-- monitor no longer present -> power off
						next_state <= PowerDown_SetAddr;
					else
						-- monitor still present
						next_state <= Wait_Int;
					end if;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- power down, [sw, p. 14ff]
			----------------------------------------------------------------------
			when PowerDown_SetAddr =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register address
				out_bus_data <= powerdown_arr(PowerDown_cycle);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= PowerDown_SetData;
				end if;

			when PowerDown_SetData =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register value
				out_bus_data <= powerdown_arr(PowerDown_cycle + 1);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= PowerDown_Next;
				end if;

			when PowerDown_Next =>
				if in_bus_ready = '1' then
					if PowerDown_cycle + 2 = powerdown_arr'length then
						-- at end of command list
						next_state <= Wait_Int;
						next_is_powered <= '0';
						next_int_triggered <= '0';
						next_PowerDown_cycle <= 0;
					else
						-- next command
						next_PowerDown_cycle <= PowerDown_cycle + 2;
						next_state <= PowerDown_SetAddr;
					end if;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- power up, [sw, p. 14ff]
			----------------------------------------------------------------------
			when PowerUp_SetAddr =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register address
				out_bus_data <= powerup_arr(powerup_cycle);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= PowerUp_SetData;
				end if;

			when PowerUp_SetData =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register value
				out_bus_data <= powerup_arr(powerup_cycle + 1);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= PowerUp_Next;
				end if;

			when PowerUp_Next =>
				out_bus_addr <= BUS_WRITEADDR;

				if in_bus_ready = '1' then
					if powerup_cycle + 2 = powerup_arr'length then
						-- at end of command list
						if CHECK_STATUS_REG = '1' then
							next_state <= Wait_Int;
						else
							next_state <= Idle;
							next_status_reg <= (5 => '1', 6 => '1', others => '0');
						end if;
						next_is_powered <= '1';
						next_int_triggered <= '0';
						next_powerup_cycle <= 0;
					else
						-- next command
						next_powerup_cycle <= powerup_cycle + 2;
						next_state <= PowerUp_SetAddr;
					end if;
				end if;

			when Idle => null;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- set-up interrupt handling and status monitoring, [sw, p. 14ff]
			----------------------------------------------------------------------
			when SetupInt_SetAddr =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register address
				out_bus_data <= setupint_arr(setupint_cycle);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= SetupInt_SetData;
				end if;

			when SetupInt_SetData =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register value
				out_bus_data <= setupint_arr(setupint_cycle + 1);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= SetupInt_Next;
				end if;

			when SetupInt_Next =>
				if in_bus_ready = '1' then
					if setupint_cycle + 2 = setupint_arr'length then
						-- at end of command list
						next_setupint_cycle <= 0;
						next_int_triggered <= '0';

						if CHECK_STATUS_REG = '1' then
							-- power down and wait for status
							next_state <= PowerDown_SetAddr;
						else
							-- directly power up
							next_state <= PowerUp_SetAddr;
						end if;
					else
						-- next command
						next_setupint_cycle <= setupint_cycle + 2;
						next_state <= SetupInt_SetAddr;
					end if;
				end if;
			----------------------------------------------------------------------


			when others =>
				next_state <= Wait_Reset;
		end case;
	end process;

end architecture;
