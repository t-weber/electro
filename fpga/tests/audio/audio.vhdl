--
-- generates an audio signal
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
		SAMPLE_BITS : natural := 16;    -- number of sample bits (for encoding the amplitude)
		SAMPLE_FREQ : natural := 44_100 -- number of sample per second (*2 channels)
	);

	port(
		in_reset : in std_logic;
		in_bitclk : in std_logic;
		in_sampleclk : in std_logic;
		in_freqsel : in std_logic;

		out_data : out std_logic;
		out_samples_end : out std_logic  -- for debugging
	);
end entity;



architecture audio_impl of audio is

	-- bit and sample counter
	signal bit_ctr, next_bit_ctr : natural range 0 to SAMPLE_BITS - 1 := 0;
	signal sec_ctr, next_sec_ctr : natural range 0 to SAMPLE_FREQ - 1 := 0;
	signal sample_ctr, next_sample_ctr : std_logic_vector(15 downto 0) := (others => '0');

	signal samples_end, next_samples_end : std_logic := '0';

	-- data amplitude
	signal amp, next_amp : std_logic_vector(SAMPLE_BITS - 1 downto 0) := (others => '0');

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
	proc_comb_bit : process(bit_ctr, amp, sample_ctr, in_freqsel) begin
		next_amp <= amp;

		if bit_ctr = 0 then
			-- set new output amplitude
			-- NOTE: data is in signed 2s-complement!
			if in_freqsel = '0' then
				next_amp <= (0 to 5 => '0', others => sample_ctr(6));
			else
				next_amp <= (0 to 5 => '0', others => sample_ctr(5));
			end if;
		else
			-- shift output amplitude bits
			next_amp <= "0" & amp(SAMPLE_BITS - 1 downto 1);
		end if;
	end process;

end architecture;
