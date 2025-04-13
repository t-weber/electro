--
-- serial-in, parallel-out
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 12-april-2025
-- @license see 'LICENSE' file
--
-- @see: https://en.wikipedia.org/wiki/Shift_register
--

library ieee;
use ieee.std_logic_1164.all;



entity sipo is
	generic(
		constant BITS : natural := 8;
		constant SHIFT_RIGHT : std_logic := '1'
	);

	port(
		-- clock and reset
		in_clk : in std_logic;
		in_rst : in std_logic;

		-- serial input
		in_serial : in std_logic;

		-- parallel output
		out_parallel : out std_logic_vector(BITS - 1 downto 0)
	);
end entity;



architecture sipo_impl of sipo is
	signal shiftreg, shiftreg_next : std_logic_vector(BITS - 1 downto 0) := (others => '0');
begin
	-- output the parallel signal
	out_parallel <= shiftreg;


	-- flip-flops
	proc_ff : process(in_clk) begin
		if rising_edge(in_clk) then
			if in_rst = '1' then
				shiftreg <= (others => '0');
			else
				shiftreg <= shiftreg_next;
			end if;
		end if;
	end process;


	shiftdir: if SHIFT_RIGHT = '1' generate

		-- combinatorics
		-- write serial signal in first shift register bit
		shiftreg_next(BITS - 1) <= in_serial;

		-- shift right
		shiftloop: for i in 1 to BITS - 1 generate
			shiftreg_next(i - 1) <= shiftreg(i);
		end generate;

--		-- combinatorics alternatively as process
--		proc_comb : process(in_serial, shiftreg) begin
--			-- default
--			shiftreg_next <= shiftreg;
--
--			-- write serial signal in first shift register bit
--			shiftreg_next(BITS - 1) <= in_serial;
--
--			-- shift right
--			shiftloop: for i in 1 to BITS - 1 loop
--				shiftreg_next(i - 1) <= shiftreg(i);
--			end loop;
--		end process;

	else generate

		-- combinatorics
		-- write serial signal in first shift register bit
		shiftreg_next(0) <= in_serial;

		-- shift left
		shiftloop: for i in 1 to BITS - 1 generate
			shiftreg_next(i) <= shiftreg(i - 1);
		end generate;

	end generate;

end architecture;
