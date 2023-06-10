--
-- multiplier
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 1-May-2023
-- @license see 'LICENSE' file
--


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.conv.all;


entity multiplier is
	generic(
		constant IN_BITS : natural := 8;
		constant OUT_BITS : natural := 8
	);
	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- start signal
		in_start : in std_logic;

		-- inputs
		in_a, in_b : in std_logic_vector(IN_BITS-1 downto 0);

		-- output
		out_prod : out std_logic_vector(OUT_BITS-1 downto 0);

		-- calculation finished?
		out_finished : out std_logic
	);
end entity;


architecture multiplier_impl of multiplier is
	-- multiplier states
	type t_state is
	(
		Reset,      -- start multiplication
		CheckShift, -- check if the current bit in a is 1 
		Shift,      -- if so, shift b to the current bit index
		Add,        -- add the shifted value to the product
		NextBit,    -- next bit
		Finished    -- multiplication finished
	);

	signal state, state_next : t_state := Reset;

	-- in_a bit index
	signal bitidx, bitidx_next : natural range 0 to IN_BITS-1;
	-- shifted b_value
	signal b_shifted, b_shifted_next : std_logic_vector(OUT_BITS-1 downto 0);
	signal b_sum : std_logic_vector(OUT_BITS-1 downto 0);
	-- current product value
	signal prod, prod_next : std_logic_vector(OUT_BITS-1 downto 0);

	-- input b with OUT_BITS length
	signal b_long : std_logic_vector(OUT_BITS-1 downto 0);	
begin

-- add shifted b value to current product value
adder : entity work.ripplecarryadder
	generic map(BITS => OUT_BITS)
	port map(in_a => prod, in_b => b_shifted, out_sum => b_sum);


-- output signals
out_prod <= prod;
out_finished <= '1' when state = Finished else '0';

b_long(OUT_BITS-1 downto IN_BITS) <= (others => '0');
b_long(IN_BITS-1 downto 0) <= in_b;


-- clock process
clk_proc : process(in_clk, in_rst) begin
	if in_rst = '1' then
		state <= Reset;
		prod <= (others => '0');
		bitidx <= 0;
		b_shifted <= (others => '0');
	elsif rising_edge(in_clk) then
		state <= state_next;
		prod <= prod_next;
		bitidx <= bitidx_next;
		b_shifted <= b_shifted_next;
	end if;
end process;


-- calculation process
calc_proc : process(all) begin
	-- save registers
	state_next <= state;
	prod_next <= prod;
	bitidx_next <= bitidx;
	b_shifted_next <= b_shifted;

	--report "State: " & t_state'image(state) &
	--	", bitidx: " & integer'image(bitidx) &
	--	", b_shifted: " & integer'image(to_int(b_shifted));

	case state is
		when Reset =>
			prod_next <= (others => '0');
			bitidx_next <= 0;
			state_next <= CheckShift;
			b_shifted_next <= (others => '0');

		when CheckShift =>
			if in_a(bitidx) = '1' then
				state_next <= Shift;
			else
				state_next <= NextBit;
			end if;
			b_shifted_next <= (others => '0');

		when Shift =>
			if bitidx /= 0 then
				b_shifted_next <=
					std_logic_vector(shift_left(unsigned(b_long), bitidx));

				--b_shifted_next(IN_BITS-1 + bitidx downto 0)
				--	<= in_b(IN_BITS-1 downto 0)
				--		& create_logvec('0', bitidx);
			else
				b_shifted_next(IN_BITS-1 downto 0) <= in_b(IN_BITS-1 downto 0);
			end if;
			state_next <= Add;

		when Add =>
			-- use internal adder
			--prod_next <= int_to_logvec(to_int(prod) + to_int(b_shifted), OUT_BITS);

			-- use adder module
			prod_next <= b_sum;

			state_next <= NextBit;

		when NextBit =>
			if bitidx = IN_BITS-1 then
				state_next <= Finished;
			else
				bitidx_next <= bitidx + 1;
				state_next <= CheckShift;
			end if;

		when Finished =>
			-- wait for start signal
			if in_start then
				state_next <= Reset;
			end if;
	end case;
end process;

end;
