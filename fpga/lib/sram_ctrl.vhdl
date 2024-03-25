--
-- controller for sram module
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date feb-2021, feb-2024
-- @license see 'LICENSE' file
--
-- References:
--	- P. P. Chu, ISBN 978-0-470-18531-5 (2008), Ch. 10, pp. 215-241,
--	  https://doi.org/10.1002/9780470231630
--

library ieee;
use ieee.std_logic_1164.all;



entity sram_ctrl is
	generic
	(
		-- address and data bus size
		constant ADDR_WIDTH : natural := 8;
		constant DATA_WIDTH : natural := 8;

		-- are the sram enables active-high or active-low?
		constant ENABLES_ACTIVE_HIGH : std_logic := '1'
	);

	port
	(
		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- choose writing or reading
		in_start, in_write : in std_logic;

		-- address
		in_addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);

		-- data writing and reading
		in_data : in std_logic_vector(DATA_WIDTH-1 downto 0);
		out_data : out std_logic_vector(DATA_WIDTH-1 downto 0);

		-- ready to accept read or write command?
		out_ready : out std_logic;

		---------------------------------------------------------------
		-- sram interface
		---------------------------------------------------------------
		out_sram_readenable : out std_logic;
		out_sram_writeenable : out std_logic;

		out_sram_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
		inout_sram_data : inout std_logic_vector(DATA_WIDTH-1 downto 0)
		---------------------------------------------------------------
	);
end entity;



architecture sram_ctrl_impl of sram_ctrl is
	-- states
	type t_state is ( Starting, Reading, Writing );
	signal state, state_next : t_state := Starting;

	-- enable signal registers
	signal read_enable, write_enable : std_logic;

	-- address and data registers
	signal addr, addr_next : std_logic_vector(ADDR_WIDTH-1 downto 0);
	signal write_data, write_data_next : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal read_data, read_data_next : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

	---------------------------------------------------------------------------
	-- outputs
	---------------------------------------------------------------------------
	gen_enables : if ENABLES_ACTIVE_HIGH = '1'
	generate       -- enable signals are active high
		out_sram_readenable <= read_enable;
		out_sram_writeenable <= write_enable;
	else generate  -- enable signals are active low
		out_sram_readenable <= not read_enable;
		out_sram_writeenable <= not write_enable;
	end generate;

	-- ready to get next address and data
	out_ready <= '1' when state_next = Starting else '0';

	-- output address to sram address bus
	out_sram_addr <= addr;

	-- write data buffer to sram's data bus (3-state)
	with write_enable select inout_sram_data <=
		write_data      when '1',
		(others => 'Z') when others;

	-- output data buffer
	out_data <= read_data;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- state machine flip-flops
	---------------------------------------------------------------------------
	proc_ff : process(in_clk, in_reset) is
	begin
		if in_reset = '1' then
			-- asynchronous reset
			addr <= (others => '0');
			read_data <= (others => '0');
			write_data <= (others => '0');
			state <= Starting;

		elsif rising_edge(in_clk) then
			-- advance states on clock
			addr <= addr_next;
			read_data <= read_data_next;
			write_data <= write_data_next;
			state <= state_next;
		end if;
	end process;
	---------------------------------------------------------------------------


	---------------------------------------------------------------------------
	-- combinatoric part of the state machine for waveform generation
	---------------------------------------------------------------------------
	proc_waves : process(state, in_write,
		in_start, in_addr, in_data, inout_sram_data,
		read_enable, write_enable,
		addr, read_data, write_data) is
	begin

		-- save registers into next cycle
		addr_next <= addr;
		read_data_next <= read_data;
		write_data_next <= write_data;
		state_next <= state;

		-- default values
		read_enable <= '0';
		write_enable <= '0';

		case state is
			--
			-- first clock cycle (select reading/writing)
			--
			when Starting =>
				addr_next <= in_addr;

				if in_start = '1' then
					if in_write = '1' then
						write_data_next <= in_data;
						state_next <= Writing;
					else
						read_enable <= '1';
						state_next <= Reading;
					end if;
				end if;

			--
			-- second clock cycle (reading)
			--
			when Reading =>
				read_enable <= '1';
				read_data_next <= inout_sram_data;
				state_next <= Starting;

			--
			-- second clock cycle (writing)
			--
			when Writing =>
				write_enable <= '1';
				state_next <= Starting;
		end case;
	end process;
	---------------------------------------------------------------------------

end architecture;
