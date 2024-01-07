--
-- multiplier
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 1-May-2023
-- @license see 'LICENSE' file
--


library ieee;
use ieee.std_logic_1164.all;
--use ieee.numeric_std.all;
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
		Add,        -- if so, shift b to the current bit index
		            -- and add the shifted value to the product
		NextBit,    -- next bit
		Finished    -- multiplication finished
	);

	signal state, state_next : t_state := Reset;

	-- in_a bit index
	signal bitidx, bitidx_next : natural range 0 to IN_BITS-1;
	-- shifted b_value
	signal b_shifted : std_logic_vector(OUT_BITS-1 downto 0);
	-- summed b value using adder module
	signal b_sum : std_logic_vector(OUT_BITS-1 downto 0);
	-- current product value
	signal prod, prod_next : std_logic_vector(OUT_BITS-1 downto 0);
begin


-- use adder module
-- add shifted b value to current product value
adder : entity work.ripplecarryadder
	generic map(BITS => OUT_BITS)
	port map(in_a => prod, in_b => b_shifted, out_sum => b_sum);


-- output signals
out_prod <= prod;
out_finished <= '1' when state = Finished else '0';


-- clock process
clk_proc : process(in_clk, in_rst) begin
	if in_rst = '1' then
		state <= Reset;
		prod <= (others => '0');
		bitidx <= 0;
	elsif rising_edge(in_clk) then
		state <= state_next;
		prod <= prod_next;
		bitidx <= bitidx_next;
	end if;
end process;


-- calculation process
calc_proc : process(all) begin
	-- save registers
	state_next <= state;
	prod_next <= prod;
	bitidx_next <= bitidx;

	-- shift in_b by bitidx to the left
	b_shifted <= (OUT_BITS-1 downto IN_BITS+bitidx => '0') & in_b
		& (bitidx-1 downto 0 => '0');

	--report "State: " & t_state'image(state) &
	--	", bitidx: " & integer'image(bitidx) &
	--	", b_shifted: " & integer'image(to_int(b_shifted));

	case state is
		when Reset =>
			prod_next <= (others => '0');
			bitidx_next <= 0;
			state_next <= CheckShift;

		when CheckShift =>
			if in_a(bitidx) = '1' then
				state_next <= Add;
			else
				state_next <= NextBit;
			end if;

		when Add =>
			-- use internal adder
			--prod_next <= int_to_logvec(to_int(prod) + to_int(b_shifted), OUT_BITS);

			-- alternatively use adder module
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
