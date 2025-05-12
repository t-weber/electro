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
		in_channelclk : in std_logic;

		out_data : out std_logic;
		out_samples_end : out std_logic  -- for debugging
	);
end entity;



architecture audio_impl of audio is

	-- bit and sample counter
	signal bit_ctr, next_bit_ctr : natural range 0 to SAMPLE_BITS - 1 := 0;
	signal sample_ctr, next_sample_ctr : natural range 0 to SAMPLE_FREQ - 1 := 0;
	signal sample_ctr_vec : std_logic_vector(15 downto 0);  -- ceil(log2(SAMPLE_FREQ))

	signal samples_end, next_samples_end : std_logic := '0';

begin

	-- counters
	next_bit_ctr <= bit_ctr + 1 when bit_ctr < SAMPLE_BITS - 1 else 0;
	next_sample_ctr <= sample_ctr + 1 when sample_ctr < SAMPLE_FREQ - 1 else 0;
	sample_ctr_vec <= nat_to_logvec(sample_ctr, sample_ctr_vec'length);


	-- sample bit output
	out_data <= sample_ctr_vec(10);
	out_samples_end <= samples_end;


	--
	-- flip-flops for bit and channel clocks
	--
	proc_ff : process(in_bitclk, in_channelclk, in_reset, samples_end) begin
		samples_end <= samples_end;
	
		-- channel clock
		if falling_edge(in_channelclk) then
			if in_reset = '1' then
				-- counter register
				sample_ctr <= 0;
				samples_end <= '0';
			else
				-- counter register
				sample_ctr <= next_sample_ctr;
				samples_end <= next_samples_end;
			end if;
		end if;

		-- bit clock
		if rising_edge(in_bitclk) then
			if in_reset = '1' then
				-- counter register
				bit_ctr <= 0;
			else
				-- counter register
				bit_ctr <= next_bit_ctr;
			end if;
		end if;
	end process;


	--
	-- combinatorics
	--
	proc_comb : process(samples_end, sample_ctr) begin
		next_samples_end <= samples_end;

		if sample_ctr = SAMPLE_FREQ - 1 then
		--if next_sample_ctr = 0 then
			next_samples_end <= not samples_end;
		end if;
	end process;

end architecture;
