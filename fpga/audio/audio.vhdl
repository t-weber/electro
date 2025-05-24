--
-- generates a simple rectangular audio signal
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 11-may-2025
-- @license see 'LICENSE' file
--
-- reference for wave form:
--   - https://www.analog.com/media/en/technical-documentation/data-sheets/ssm2603.pdf, p. 16
--


library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity audio is
	generic(
		TONE_BITS   : natural := 16;     -- number of bits for the tone frequency
		FRAME_BITS  : natural := 32;     -- number of bits in a sample frame
		SAMPLE_BITS : natural := 16;     -- number of sample bits (for encoding the amplitude)
		SAMPLE_FREQ : natural := 44_100  -- number of sample per second (*2 channels)
	);

	port(
		in_reset : in std_logic;
		--in_freqsel : in std_logic;
		in_bitclk : in std_logic;
		in_sampleclk : in std_logic;

		in_tone_hz : in std_logic_vector(TONE_BITS - 1 downto 0);

		out_data : out std_logic;        -- current sample bit
		out_samples_end : out std_logic  -- for debugging
	);
end entity;



architecture audio_impl of audio is

	-- bit and sample counter
	signal bit_ctr, next_bit_ctr : natural range 0 to FRAME_BITS - 1 := 0;
	signal sec_ctr, next_sec_ctr : natural range 0 to SAMPLE_FREQ - 1 := 0;
	signal sample_ctr, next_sample_ctr : std_logic_vector(15 downto 0) := (others => '0');
	signal tone_clk : std_logic;

	signal samples_end, next_samples_end : std_logic := '0';

	-- data amplitude
	signal amp, next_amp : std_logic_vector(FRAME_BITS - 1 downto 0) := (others => '0');

	-- generated tone frequency
	signal tone_hz : std_logic_vector(TONE_BITS - 1 downto 0) := 16d"330";

begin

	-- counters
	next_bit_ctr <= bit_ctr + 1 when bit_ctr < bit_ctr'right else 0;
	next_sec_ctr <= sec_ctr + 1 when sec_ctr < sec_ctr'right else 0;
	next_sample_ctr <= inc_logvec(sample_ctr, 1);


	-- sample bit output
	out_data <= amp(0);
	out_samples_end <= samples_end;


	--
	-- flip-flops for bit and channel clocks
	--
	proc_ff : process(in_bitclk, in_sampleclk, in_reset, samples_end) begin
		samples_end <= samples_end;

		if in_reset = '1' then
			sec_ctr <= 0;
			samples_end <= '0';
			sample_ctr <= (others => '0');

			bit_ctr <= 0;
			amp <= (others => '0');
		else
			-- channel clock
			if falling_edge(in_sampleclk) then
				sec_ctr <= next_sec_ctr;
				samples_end <= next_samples_end;
				sample_ctr <= next_sample_ctr;
			end if;

			-- bit clock
			if rising_edge(in_bitclk) then
				bit_ctr <= next_bit_ctr;
				amp <= next_amp;
			end if;
		end if;
	end process;


	--
	-- combinatorics for sample counter
	--
	proc_comb_sample : process(samples_end, sec_ctr) begin
		next_samples_end <= samples_end;

		if sec_ctr = SAMPLE_FREQ - 1 then
			next_samples_end <= not samples_end;
		end if;
	end process;


	--
	-- combinatorics for bit counter
	--
	proc_comb_bit : process(bit_ctr, amp, tone_clk) begin
		next_amp <= amp;

		if bit_ctr = 0 then
			-- set new output amplitude
			-- NOTE: data is in signed 2s-complement!
			next_amp <= (0 to 2 => '0', FRAME_BITS - 1 downto SAMPLE_BITS - 1 => '0', others => tone_clk);
		else
			-- shift output amplitude bits
			next_amp <= "0" & amp(FRAME_BITS - 1 downto 1);
		end if;
	end process;


	--
	-- select frequency of test tone to generate
	--
	--proc_tonesel : process(in_freqsel) begin
	--	if in_freqsel = '1' then
	--		tone_hz <= 32d"660";
	--	else
	--		tone_hz <= 32d"330";
	--	end if;
	--end process;

	-- or use externally given tone frequency
	tone_hz <= in_tone_hz;


	--
	-- clock for tone generation
	--
	tonegen : entity work.clkgen_var
		generic map(MAIN_HZ => SAMPLE_FREQ, HZ_BITS => TONE_BITS)
		port map(in_clk => in_sampleclk, in_reset => in_reset, out_clk => tone_clk,
			in_clk_hz => tone_hz, in_clk_shift => '0', in_clk_init => '0');

end architecture;
