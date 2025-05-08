--
-- serial controller for 2-wire interface
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date apr-2024
-- @license see 'LICENSE' file
--
-- Reference:
--   - https://www.ti.com/lit/pdf/slva704
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity serial_2wire is
	generic(
		-- clocks
		constant MAIN_HZ : natural := 50_000_000;
		constant SERIAL_HZ : natural := 10_000;

		-- target address and word lengths
		constant ADDR_BITS : natural := 8;
		constant BITS : natural := 8;
		constant LOWBIT_FIRST : std_logic := '0';

		-- continue after errors
		constant IGNORE_ERROR : std_logic := '0'
	);

	port(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- serial clock and data
		inout_clk : inout std_logic;
		inout_serial : inout std_logic;

		-- enable transmission
		in_enable : in std_logic;
		in_write : in std_logic;

		-- ready and error flags
		out_ready : out std_logic;
		out_err : out std_logic;

		-- current word transmitted or received?
		out_next_word : out std_logic;

		-- target addresses for writing and reading
		in_addr_write : in std_logic_vector(ADDR_BITS-1 downto 0);
		in_addr_read : in std_logic_vector(ADDR_BITS-1 downto 0);

		-- parallel input data (FPGA -> IC)
		in_parallel : in std_logic_vector(BITS-1 downto 0);

		-- parallel output data (IC -> FPGA)
		out_parallel : out std_logic_vector(BITS-1 downto 0)
	);
end entity;



architecture serial_2wire_impl of serial_2wire is
	-- states and next state logic
	type t_serial_state is (
		Ready, Error,
		TransmitWriteAddress, TransmitReadAddress,
		Transmit, Receive,
		SendStart, SendStart2, SendRepeatedStart,
		SendStop, SendStop2,
		ReceiveAck, SendAck, SendNoAck
	);
	signal serial_state, next_serial_state : t_serial_state := Ready;
	signal state_afterstart, next_state_afterstart : t_serial_state := Ready;
	signal state_afterstop, next_state_afterstop : t_serial_state := Ready;
	signal state_afterack, next_state_afterack : t_serial_state := Ready;

	-- serial clock
	signal serial_clk, serial_clk_z : std_logic := '0';

	-- bit counter
	signal bit_ctr, next_bit_ctr : natural range 0 to BITS-1 := 0;

	-- bit counter with correct ordering
	signal actual_bit_ctr : natural range 0 to BITS-1 := 0;

	-- parallel input buffer (FPGA -> IC)
	signal parallel_fromfpga, next_parallel_fromfpga
		: std_logic_vector(BITS-1 downto 0) := (others => '0');

	-- serial output buffer (FPGA -> IC)
	signal serial_fromfpga : std_logic := '0';
	signal serial_addr_write, serial_addr_read : std_logic := '0';

	-- parallel output buffer (IC -> FPGA)
	signal parallel_tofpga, next_parallel_tofpga
		: std_logic_vector(BITS-1 downto 0) := (others => '0');

begin
	--
	-- generate serial clock
	--
	serial_clkgen : entity work.clkgen
		generic map(MAIN_HZ => MAIN_HZ, CLK_HZ => SERIAL_HZ, CLK_INIT => '1')
		port map(in_clk => in_clk, in_reset => in_reset,
			out_clk => serial_clk);


	--
	-- output serial clock
	-- inactive 'Z' and trigger on falling edge
	--
	serial_clk_z <= '0' when serial_clk = '0' else 'Z';

	inout_clk <= serial_clk_z
		when serial_state = Transmit or serial_state = Receive
		  or serial_state = TransmitWriteAddress or serial_state = TransmitReadAddress
		  or serial_state = ReceiveAck or serial_state = SendAck or serial_state = SendNoAck
		  or serial_state = SendStop or serial_state = SendRepeatedStart
		else 'Z';


	--
	-- state and data flip-flops for serial clock
	--
	serial_ff : process(serial_clk, in_reset) begin
		-- reset
		if in_reset = '1' then
			-- state registers
			serial_state <= Ready;
			state_afterstart <= Ready;
			state_afterstop <= Ready;
			state_afterack <= Ready;

			-- counter register
			bit_ctr <= 0;

			-- parallel data registers
			parallel_fromfpga <= (others => '0');
			parallel_tofpga <= (others => '0');

		-- clock
		elsif falling_edge(serial_clk) then
			-- state registers
			serial_state <= next_serial_state;
			state_afterstart <= next_state_afterstart;
			state_afterstop <= next_state_afterstop;
			state_afterack <= next_state_afterack;

			-- counter register
			bit_ctr <= next_bit_ctr;

			-- parallel data registers
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
	-- input parallel data (FPGA -> IC)
	--
	proc_input : process(in_write, in_enable, in_parallel, parallel_fromfpga)
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
	serial_addr_write <= in_addr_write(actual_bit_ctr);
	serial_addr_read <= in_addr_read(actual_bit_ctr);


	--
	-- output parallel data (IC -> FPGA)
	--
	out_parallel <= parallel_tofpga;


	--
	-- input serial data (IC -> FPGA)
	--
	proc_tofpga : process(serial_state, inout_serial,
		parallel_tofpga, actual_bit_ctr)
	begin
		next_parallel_tofpga <= parallel_tofpga;

		if serial_state = Receive then
			next_parallel_tofpga(actual_bit_ctr) <= inout_serial;
		end if;
	end process;


	--
	-- output serial data (FPGA -> IC)
	--
	proc_fromfpga : process(serial_state, serial_fromfpga,
		serial_addr_write, serial_addr_read)
	begin
		inout_serial <= 'Z';

		case serial_state is
			-------------------------------------------------------
			-- address transmission
			-------------------------------------------------------
			when TransmitWriteAddress =>
				if serial_addr_write = '0' then
					inout_serial <= '0';
				end if;

			when TransmitReadAddress =>
				if serial_addr_read = '0' then
					inout_serial <= '0';
				end if;
			-------------------------------------------------------

			when Transmit =>
				if serial_fromfpga = '0' then
					inout_serial <= '0';
				end if;

			-------------------------------------------------------
			-- start signal: sda: falling edge, scl: 'z'
			-------------------------------------------------------
			when SendStart =>
				inout_serial <= 'Z';

			when SendStart2 =>
				inout_serial <= '0';

			when SendRepeatedStart =>
				-- same as SendStart, but with serial clock active
				inout_serial <= 'Z';
			-------------------------------------------------------

			-------------------------------------------------------
			-- stop signal: sda: rising edge, scl: 'z'
			-------------------------------------------------------
			when SendStop =>
				inout_serial <= '0';

			when SendStop2 =>
				inout_serial <= 'Z';
			-------------------------------------------------------

			-------------------------------------------------------
			-- acknowledge signal: sda: '0'
			-------------------------------------------------------
			when SendAck =>
				inout_serial <= '0';

			when SendNoAck =>
				inout_serial <= 'Z';
			-------------------------------------------------------

			when others => null;
		end case;
	end process;


	--
	-- state combinatorics
	--
	proc_comb : process(in_enable, in_write, serial_state,
		state_afterstart, state_afterstop, state_afterack,
		bit_ctr, inout_serial)
	begin
		-- defaults
		next_serial_state <= serial_state;
		next_state_afterstart <= state_afterstart;
		next_state_afterstop <= state_afterstop;
		next_state_afterack <= state_afterack;
		next_bit_ctr <= bit_ctr;

		out_next_word <= '0';
		out_ready <= '0';
		out_err <= '0';

		report "serial_2wire: " & t_serial_state'image(serial_state);

		-- state machine
		case serial_state is
			-- wait for enable signal
			when Ready =>
				next_bit_ctr <= 0;
				if in_enable = '1' then
					next_serial_state <= SendStart;
					next_state_afterstart <= TransmitWriteAddress;
				else
					out_ready <= '1';
				end if;

			when Error =>
				out_err <= '1';

			-------------------------------------------------------
			-- write target address
			-------------------------------------------------------
			when TransmitWriteAddress =>
				-- end of word?
				if bit_ctr = ADDR_BITS - 1 then
					next_bit_ctr <= 0;

					next_serial_state <= ReceiveAck;
					next_state_afterack <= Transmit;
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

			when TransmitReadAddress =>
				-- end of word?
				if bit_ctr = ADDR_BITS - 1 then
					next_bit_ctr <= 0;

					next_serial_state <= ReceiveAck;
					next_state_afterack <= Receive;
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;
			-------------------------------------------------------

			-------------------------------------------------------
			-- serialise parallel data and send it to target
			-------------------------------------------------------
			when Transmit =>
				-- end of word?
				if bit_ctr = BITS - 1 then
					out_next_word <= '1';
					next_bit_ctr <= 0;

					next_serial_state <= ReceiveAck;
					if in_write = '1' then
						next_state_afterack <= Transmit;
					else
						next_state_afterack <= SendRepeatedStart;
						next_state_afterstart <= TransmitReadAddress;
					end if;
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

				-- enable signal not active anymore?
				if in_enable = '0' then
					if bit_ctr = BITS - 1 then
						next_serial_state <= ReceiveAck;
						next_state_afterack <= SendStop;
					else
						next_serial_state <= SendStop;
					end if;
					next_state_afterstop <= Ready;
				end if;
			-------------------------------------------------------

			-------------------------------------------------------
			-- read serial data from target
			-------------------------------------------------------
			when Receive =>
				-- end of word?
				if bit_ctr = BITS - 1 then
					out_next_word <= '1';
					next_bit_ctr <= 0;

					next_serial_state <= SendAck;
					next_state_afterack <= Receive;
				else
					-- next bit of the word
					next_bit_ctr <= bit_ctr + 1;
				end if;

				-- enable signal not active anymore?
				if in_enable = '0' then
					if bit_ctr = BITS - 1 then
						next_serial_state <= SendNoAck;
						next_state_afterack <= SendStop;
					else
						next_serial_state <= SendStop;
					end if;
					next_state_afterstop <= Ready;
				end if;
			-------------------------------------------------------

			-------------------------------------------------------
			-- send start signal
			-------------------------------------------------------
			when SendStart =>
				next_serial_state <= SendStart2;

			when SendStart2 =>
				next_serial_state <= state_afterstart;

			when SendRepeatedStart =>
				next_serial_state <= SendStart2;
			-------------------------------------------------------

			-------------------------------------------------------
			-- send stop signal
			-------------------------------------------------------
			when SendStop =>
				next_serial_state <= SendStop2;

			when SendStop2 =>
				next_serial_state <= state_afterstop;
			-------------------------------------------------------

			-------------------------------------------------------
			-- receive or send acknowledge signal
			-------------------------------------------------------
			when ReceiveAck =>
				if inout_serial = '0' or IGNORE_ERROR = '1' then
					next_serial_state <= state_afterack;
				else
					next_serial_state <= Error;
				end if;

			when SendAck =>
				next_serial_state <= state_afterack;

			when SendNoAck =>
				next_serial_state <= state_afterack;
			-------------------------------------------------------

			-- default state
			when others =>
				next_serial_state <= Ready;
		end case;
	end process;

end architecture;
