--
-- parallel-in, serial-out
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 12-april-2025
-- @license see 'LICENSE' file
--
-- @see: https://en.wikipedia.org/wiki/Shift_register
--

library ieee;
use ieee.std_logic_1164.all;



entity piso is
	generic(
		constant BITS : natural := 8;
		constant SHIFT_RIGHT : std_logic := '1'
	);

	port(
		-- clock and reset
		in_clk : in std_logic;
		in_rst : in std_logic;

		-- parallel input
		in_parallel : in std_logic_vector(BITS - 1 downto 0);
		in_capture : in std_logic;
		in_rotate : in std_logic;

		-- serial output
		out_serial : out std_logic
	);
end entity;



architecture piso_impl of piso is
	signal shiftreg, shiftreg_next : std_logic_vector(BITS - 1 downto 0) := (others => '0');
begin
	-- flip-flops
	proc_ff : process(in_clk) begin
		if rising_edge(in_clk) then
			if in_rst = '1' then
				shiftreg <= (others => '0');
			else
				shiftreg <= shiftreg_next;
			end if;

			report "shiftreg = 0x" & to_hstring(shiftreg) & " = 0b" & to_string(shiftreg);
		end if;
	end process;


	-- combinatorics
	shiftdir : if SHIFT_RIGHT = '1' generate

		out_serial <= shiftreg(0);

		proc_comb : process(in_parallel, in_capture, shiftreg) begin
			-- default
			shiftreg_next <= shiftreg;

			-- capture parallel input
			if in_capture = '1' then
				shiftreg_next <= in_parallel;
			else
				if in_rotate = '1' then
					shiftreg_next(BITS - 1) <= shiftreg(0);
				else
					shiftreg_next(BITS - 1) <= '0';
				end if;

				-- shift right
				shiftloop: for i in 1 to BITS - 1 loop
					shiftreg_next(i - 1) <= shiftreg(i);
				end loop;
			end if;
		end process;

	else generate

		out_serial <= shiftreg(BITS - 1);

		proc_comb : process(in_parallel, in_capture, shiftreg) begin
			-- default
			shiftreg_next <= shiftreg;

			-- capture parallel input
			if in_capture = '1' then
				shiftreg_next <= in_parallel;
			else
				if in_rotate = '1' then
					shiftreg_next(0) <= shiftreg(BITS - 1);
				else
					shiftreg_next(0) <= '0';
				end if;

				-- shift left
				shiftloop: for i in 1 to BITS - 1 loop
					shiftreg_next(i) <= shiftreg(i - 1);
				end loop;
			end if;
		end process;

	end generate;

end architecture;
