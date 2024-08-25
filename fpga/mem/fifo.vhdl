--
-- fifo buffer
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-aug-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity fifo is
	generic(
		constant ADDR_BITS : natural := 3;
		constant WORD_BITS : natural := 8
	);

	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- ready signals
		out_ready_to_insert : out std_logic;
		out_ready_to_remove : out std_logic;

		-- buffer empty?
		out_empty : out std_logic;

		-- insert an element to the back
		in_insert : in std_logic;
		-- remove an element from the front
		in_remove : in std_logic;

		-- data to insert
		in_data : in  std_logic_vector(WORD_BITS - 1 downto 0);

		-- data at the back pointer
		out_back : out std_logic_vector(WORD_BITS - 1 downto 0)
	);
end entity;



architecture fifo_impl of fifo is
	constant NUM_WORDS : natural := 2**ADDR_BITS;

	subtype t_word is std_logic_vector(WORD_BITS - 1 downto 0);
	type t_words is array(0 to NUM_WORDS - 1) of t_word;

	-- buffer memory
	signal words : t_words := (others => (others => '0'));

	-- front and back pointers
	signal fp, next_fp : std_logic_vector(ADDR_BITS - 1 downto 0) := (others => '0');
	signal bp, next_bp : std_logic_vector(ADDR_BITS - 1 downto 0) := (others => '0');

	-- state of front pointer process
	type t_state_fp is (
		WaitFPCommand,
		Insert, Insert2
	);
	signal state_fp, next_state_fp : t_state_fp := WaitFPCommand;

	-- state of back pointer process
	type t_state_bp is (
		WaitBPCommand,
		CheckRemove, Remove
	);
	signal state_bp, next_state_bp : t_state_bp := WaitBPCommand;

	signal empty : std_logic := '1';

begin

	-- output data at back pointer
	out_back <= words(to_int(bp));

	-- buffer empty?
	empty <= '1' when fp = bp else '0';
	out_empty <= empty;


	--
	-- flip-flops
	--
	process(in_clk) begin
		if rising_edge(in_clk) then
			if in_rst = '1' then
				state_bp <= WaitBPCommand;
				state_fp <= WaitFPCommand;
				fp <= (others => '0');
				bp <= (others => '0');
			else
				state_bp <= next_state_bp;
				state_fp <= next_state_fp;
				fp <= next_fp;
				bp <= next_bp;
			end if;
		end if;
	end process;


	--
	-- front-pointer / element insertion state combinatorics
	--
	process(state_fp, fp, in_insert, in_data) begin
		next_state_fp <= state_fp;
		next_fp <= fp;

		out_ready_to_insert <= '0';

		--report "*** FIFO: state_fp = " & t_state_fp'image(state_fp)
		--	& ", fp = 0x" & to_hstring(fp)
		--	& ", data = 0x" & to_hstring(in_data);

		case state_fp is
			when WaitFPCommand =>
				if in_insert = '1' then
					next_state_fp <= Insert;
				else
					out_ready_to_insert <= '1';
				end if;

			-- insert an element to the front
			when Insert =>
				-- write data to front pointer
				words(to_int(fp)) <= in_data;
				next_state_fp <= Insert2;

			when Insert2 =>
				-- increment front pointer
				next_fp <= inc_logvec(fp, 1);
				next_state_fp <= WaitFPCommand;
		end case;
	end process;


	--
	-- back-pointer / element removal state combinatorics
	--
	process(state_bp, bp, in_remove) begin
		next_state_bp <= state_bp;
		next_bp <= bp;

		out_ready_to_remove <= '0';

		--report "*** FIFO: state_bp = " & t_state_bp'image(state_bp)
		--	& ", bp = 0x" & to_hstring(bp);

		case state_bp is
			when WaitBPCommand =>
				if in_remove = '1' then
					next_state_bp <= CheckRemove;
				else
					out_ready_to_remove <= '1';
				end if;

			when CheckRemove =>
				-- only remove element if the buffer is not empty
				if empty = '1' then
					next_state_bp <= WaitBPCommand;
				else
					next_state_bp <= Remove;
				end if;

			-- remove an element at the back
			when Remove =>
				-- increment back pointer
				next_bp <= inc_logvec(bp, 1);
				next_state_bp <= WaitBPCommand;
		end case;
	end process;

end architecture;
