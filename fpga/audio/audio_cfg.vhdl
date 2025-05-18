--
-- audio output configuration via 2-wire serial bus
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 3-may-2025
-- @license see 'LICENSE' file
--
-- references for audio chip:
--   - [hw] https://www.analog.com/media/en/technical-documentation/data-sheets/ssm2603.pdf
--
-- note: serial data and clock signal need to be declared 3-state (high-Z for idle state)
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity audio_cfg is
	generic(
		-- clock
		constant MAIN_CLK : natural := 50_000_000;

		-- word length and address of the serial bus
		constant BUS_ADDRBITS : natural := 8;
		constant BUS_DATABITS : natural := 8;

		-- addresses, see [hw, p. 17]
		--constant BUS_WRITEADDR : std_logic_vector(BUS_ADDRBITS - 1 downto 0) := x"34";
		--constant BUS_READADDR : std_logic_vector(BUS_ADDRBITS - 1 downto 0) := x"35"
		constant BUS_WRITEADDR : std_logic_vector(7 downto 0) := x"34";
		constant BUS_READADDR : std_logic_vector(7 downto 0) := x"35"
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- serial bus interface
		in_bus_ready : in std_logic;
		in_bus_data : in std_logic_vector(BUS_DATABITS - 1 downto 0);
		in_bus_byte_finished : in std_logic;

		-- serial bus interface
		out_bus_enable : out std_logic;
		out_bus_addr : out std_logic_vector(BUS_ADDRBITS - 1 downto 0);
		out_bus_data : out std_logic_vector(BUS_DATABITS - 1 downto 0);

		-- active status bit
		out_active : out std_logic;
		out_status : out std_logic_vector(BUS_DATABITS - 1 downto 0)
	);
end entity;



architecture audio_cfg_impl of audio_cfg is
	-- states
	type t_state is ( Reset_Wait, Idle,
		ReadStatus_SetAddr, ReadStatus_SetReg, ReadStatus_GetData,
		Config_SetAddr, Config_SetData, Config_Wait, Config_Next,
		PowerUp_Wait, PowerUp_SetAddr, PowerUp_SetData, PowerUp_Wait2, PowerUp_Next);

	signal state, next_state : t_state := Reset_Wait;

	signal last_bus_byte_finished, bus_cycle : std_logic := '0';

	-- reset delay and counter for busy wait
	constant const_wait_reset : natural := MAIN_CLK/1000*200;  -- 200 ms
	constant const_wait_power : natural := MAIN_CLK/1000*100;  -- 100 ms
	constant const_wait_config : natural := MAIN_CLK/1000*10;  -- 10 ms
	signal wait_counter, wait_counter_max : natural range 0 to const_wait_reset := 0;

	-- status register
	signal status_reg, next_status_reg : std_logic_vector(BUS_DATABITS - 1 downto 0) := (others => '0');

	-- all video outputs on?
	signal is_powered, next_is_powered : std_logic := '0';

	-- power up sequence options, see [hw, p. 19]
	constant LINEIN_OFF       : std_logic := '1';
	constant MIKE_OFF         : std_logic := '1';
	constant ADC_OFF          : std_logic := '1';
	constant DAC_OFF          : std_logic := '0';
	constant OSCI_OFF         : std_logic := '1';
	constant CLOCKOUT_OFF     : std_logic := '1';
	constant ALL_OFF          : std_logic := '0';
	constant ADC_HIGHPASS_OFF : std_logic := '0';
	constant ADC_DC_OFFS      : std_logic := '0';
	constant ADC_MUTE         : std_logic := '1';
	constant DAC_MUTE         : std_logic := '0';
	constant DAC_SELECT       : std_logic := '1';
	constant LINEIN_SELECT    : std_logic := '0';
	constant MIKE_SELECT      : std_logic := '0';
	constant MIKE_MUTE        : std_logic := '1';
	constant MIKE_BOOST       : std_logic := '0';
	constant MIKE_GAIN_ENABLE : std_logic := '0';
	constant INVERT_BCLK      : std_logic := '0';
	constant CONTROL_CLOCKS   : std_logic := '0';  -- output (1) or receive (0) clock signals
	constant DAC_SWAP         : std_logic := '0';
	constant CLK_POLARITY     : std_logic := '0';
	constant CLK_OVERSAMPLE   : std_logic := '0';
	constant SERIAL_MODE      : std_logic := '0';
	constant ADC_VOLUME       : std_logic_vector(5 downto 0) := 6x"00";
	constant DAC_VOLUME       : std_logic_vector(6 downto 0) := 7x"79";
	constant DEEMPHASIS       : std_logic_vector(1 downto 0) := "00";
	constant MIKE_GAIN        : std_logic_vector(1 downto 0) := "00";
	constant WORD_SIZE        : std_logic_vector(1 downto 0) := "00";  -- 16 bit
	constant DAC_FORMAT       : std_logic_vector(1 downto 0) := "10";
	constant CLK_DIVS         : std_logic_vector(1 downto 0) := "00";
	constant CLK_RATE         : std_logic_vector(3 downto 0) := "1010";  -- 44.1 kHz

	-- configuration sequence, see [hw, pp. 17, 19]
	type t_config_arr is array(0 to 11 - 1) of std_logic_vector(2*BUS_DATABITS - 1 downto 0);
	constant config_arr : t_config_arr := (
		-- reg: 7 bits, val: 9 bits
		7x"0f" & "000000000",  -- reset, [hw, p. 27]
		7x"09" & "000000000",  -- inactive, [hw, p. 27]
		7x"06" & '0' & ALL_OFF & CLOCKOUT_OFF & OSCI_OFF & '1' & DAC_OFF & ADC_OFF & MIKE_OFF & LINEIN_OFF,  -- power (active low), [hw, p. 23]

		7x"00" & '0' & ADC_MUTE & '0' & ADC_VOLUME,  -- adc volumne (left), [hw, p. 20]
		7x"01" & '0' & ADC_MUTE & '0' & ADC_VOLUME,  -- adc volumne (right), [hw, p. 21]
		7x"02" & "00" & DAC_VOLUME,  -- dac volumne (left), [hw, p. 21]
		7x"03" & "00" & DAC_VOLUME,  -- dac volumne (right), [hw, p. 22]

		7x"04" & '0' & MIKE_GAIN & MIKE_GAIN_ENABLE & DAC_SELECT & LINEIN_SELECT & MIKE_SELECT & MIKE_MUTE & MIKE_BOOST,  -- [hw, p. 22]
		7x"05" & "0000" & ADC_DC_OFFS & DAC_MUTE & DEEMPHASIS & ADC_HIGHPASS_OFF,  -- [hw, pp. 22, 23]

		7x"07" & '0' & INVERT_BCLK & CONTROL_CLOCKS & DAC_SWAP & CLK_POLARITY & WORD_SIZE & DAC_FORMAT,  -- [hw, p. 24]
		7x"08" & '0' & CLK_DIVS & CLK_RATE & CLK_OVERSAMPLE & SERIAL_MODE  -- [hw, p. 24]
	);

	-- power up sequence, see [hw, pp. 17, 19]
	type t_powerup_arr is array(0 to 2 - 1) of std_logic_vector(2*BUS_DATABITS - 1 downto 0);
	constant powerup_arr : t_powerup_arr := (
		-- reg: 7 bits, val: 9 bits
		7x"09" & "000000001",  -- active, [hw, p. 27]
		7x"06" & '0' & ALL_OFF & CLOCKOUT_OFF & OSCI_OFF & '0' & DAC_OFF & ADC_OFF & MIKE_OFF & LINEIN_OFF   -- power (active low), [hw, p. 23]
	);

	signal config_cycle, next_config_cycle : natural range 0 to config_arr'length := 0;

begin

	-- output status registers
	out_active <= status_reg(0);
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
			state <= Reset_Wait;

			-- command counter
			config_cycle <= 0;

			-- status register
			status_reg <= (others => '0');

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
			config_cycle <= next_config_cycle;

			-- status register
			status_reg <= next_status_reg;

			-- all video outputs on?
			is_powered <= next_is_powered;

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
		in_bus_ready, in_bus_data,
		bus_cycle, config_cycle,
		status_reg, is_powered)
	begin
		-- defaults
		next_state <= state;
		next_config_cycle <= config_cycle;
		next_status_reg <= status_reg;
		next_is_powered <= is_powered;
		wait_counter_max <= 0;

		out_bus_enable <= '0';
		out_bus_addr <= BUS_READADDR;
		out_bus_data <= (others => '0');


		-- fsm
		case state is

			--
			-- reset delay
			--
			when Reset_Wait =>
				wait_counter_max <= const_wait_reset;
				if wait_counter = wait_counter_max then
					next_state <= Config_SetAddr;
				end if;


			--
			-- setup finished
			--
			when Idle =>
				null;


			----------------------------------------------------------------------
			-- configuration
			----------------------------------------------------------------------
			when Config_SetAddr =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register address + 1 data bit
				out_bus_data <= config_arr(config_cycle)(2*BUS_DATABITS - 1 downto BUS_DATABITS);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= Config_SetData;
				end if;

			when Config_SetData =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write the rest of the value bits
				out_bus_data <= config_arr(config_cycle)(BUS_DATABITS - 1 downto 0);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= Config_Wait;
				end if;

			when Config_Wait =>
				wait_counter_max <= const_wait_config;
				if wait_counter = wait_counter_max then
					next_state <= Config_Next;
				end if;

			when Config_Next =>
				out_bus_addr <= BUS_WRITEADDR;

				if in_bus_ready = '1' then
					if config_cycle + 1 = config_arr'length then
						-- at end of command list
							next_state <= PowerUp_Wait;
						next_is_powered <= '1';
						next_config_cycle <= 0;
					else
						-- next command
						next_config_cycle <= config_cycle + 1;
						next_state <= Config_SetAddr;
					end if;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- power up
			----------------------------------------------------------------------
			--
			-- power up delay
			--
			when PowerUp_Wait =>
				wait_counter_max <= const_wait_power;
				if wait_counter = wait_counter_max then
					next_state <= PowerUp_SetAddr;
				end if;


			when PowerUp_SetAddr =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write register address + 1 data bit
				out_bus_data <= powerup_arr(config_cycle)(2*BUS_DATABITS - 1 downto BUS_DATABITS);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= PowerUp_SetData;
				end if;

			when PowerUp_SetData =>
				out_bus_addr <= BUS_WRITEADDR;

				-- write the rest of the value bits
				out_bus_data <= powerup_arr(config_cycle)(BUS_DATABITS - 1 downto 0);
				out_bus_enable <= '1';

				if bus_cycle = '1' then
					next_state <= PowerUp_Wait2;
				end if;

			when PowerUp_Wait2 =>
				wait_counter_max <= const_wait_config;
				if wait_counter = wait_counter_max then
					next_state <= PowerUp_Next;
				end if;

			when PowerUp_Next =>
				out_bus_addr <= BUS_WRITEADDR;

				if in_bus_ready = '1' then
					if config_cycle + 1 = powerup_arr'length then
						-- at end of command list
							next_state <= ReadStatus_SetAddr;
						next_is_powered <= '1';
						next_config_cycle <= 0;
					else
						-- next command
						next_config_cycle <= config_cycle + 1;
						next_state <= PowerUp_SetAddr;
					end if;
				end if;
			----------------------------------------------------------------------


			----------------------------------------------------------------------
			-- read active status register
			----------------------------------------------------------------------
			when ReadStatus_SetAddr =>
				out_bus_addr <= BUS_WRITEADDR;
				-- active status register, address 9
				out_bus_data <= 7x"09" & '0';
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
					next_state <= Idle;
				end if;
			----------------------------------------------------------------------


			when others =>
				next_state <= Reset_Wait;
		end case;
	end process;

end architecture;
