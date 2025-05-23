--
-- generates a (slower) clock with a variable frequency
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-nov-2023, 24-may-2025
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity clkgen_var is
	generic(
		-- clock rates
		constant MAIN_HZ : natural := 50_000_000;
		constant HZ_BITS : natural := 32  -- ceil(log2(MAIN_HZ))
	);

	port(
		-- generated clock frequency
		in_clk_hz : in std_logic_vector(HZ_BITS - 1 downto 0);
		in_clk_shift : in std_logic;

		-- reset value of clock
		in_clk_init : in std_logic;

		-- main clock and reset
		in_clk, in_reset : in std_logic;

		-- output clock
		out_clk : out std_logic
	);
end entity;



architecture clkgen_impl of clkgen_var is

	-- generated clock
	signal clk_hz : natural := MAIN_HZ;
	signal clk : std_logic := '0';

	signal clk_ctr_max : natural := MAIN_HZ;
	signal clk_ctr_shifted : natural := 0;


	-- clock shift
	pure function get_clk_shift(is_shifted : std_logic; slow_clk_hz : natural) return natural is
		variable shifted_clk : natural := 0;
	begin
		if is_shifted = '1' then
			shifted_clk := MAIN_HZ / slow_clk_hz / 2 - MAIN_HZ / slow_clk_hz / 4;
		else
			shifted_clk := 0;
		end if;

		return shifted_clk;
	end function;

begin

	-- output slower clock
	out_clk <= clk;
	clk_hz <= to_int(in_clk_hz);


	--
	-- calculate counter maximum
	--
	ctr_proc : process(clk_hz, in_clk_shift)
	begin
		clk_ctr_max <= MAIN_HZ / clk_hz / 2 - 1;
		clk_ctr_shifted <= get_clk_shift(is_shifted => in_clk_shift, slow_clk_hz => clk_hz);

		--report "ref_clk = " & natural'image(MAIN_HZ) & " Hz"
		--	& ", req_clk = " & natural'image(clk_hz) & " Hz"
		--	& ", gen_clk = " & natural'image(MAIN_HZ / (clk_ctr_max*2 + 2)) & " Hz"
		--	& ", clk_ctr_max = " & natural'image(clk_ctr_max)
		--	& ", clk_ctr_shifted = " & natural'image(clk_ctr_shifted);
	end process;


	--
	-- generate clock
	--
	proc_clk : process(in_clk, in_reset, in_clk_init, clk_ctr_shifted)
		variable clk_ctr : natural range 0 to MAIN_HZ - 1 := 0;
	begin
		-- asynchronous reset
		if in_reset = '1' then
			clk_ctr := clk_ctr_shifted;
			clk <= in_clk_init;

		-- clock
		elsif rising_edge(in_clk) then
			if clk_ctr >= clk_ctr_max then
				clk <= not clk;
				clk_ctr := 0;
			else
				clk_ctr := clk_ctr + 1;
			end if;
		end if;
	end process;

end architecture;
