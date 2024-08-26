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
		in_clk_insert, in_clk_remove : in std_logic;
		in_rst : in std_logic;

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
		in_data : in std_logic_vector(WORD_BITS - 1 downto 0);

		-- data at the back pointer
		out_back : out std_logic_vector(WORD_BITS - 1 downto 0)
	);
end entity;



--
-- standard implementation with checks
--
architecture fifo_impl of fifo is
	-- buffer memory size
	constant NUM_WORDS : natural := 2**ADDR_BITS;

	-- word type
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
		Insert
	);
	signal state_fp, next_state_fp : t_state_fp := WaitFPCommand;

	-- state of back pointer process
	type t_state_bp is (
		WaitBPCommand,
		Remove
	);
	signal state_bp, next_state_bp : t_state_bp := WaitBPCommand;

	signal empty : std_logic := '1';

begin

	-- output data at back pointer
	out_back <= words(to_int(bp));

	-- buffer empty?
	empty <= '1' when fp = bp else '0';
	out_empty <= empty;


	-----------------------------------------------------------------------
	--
	-- front-pointer / element insertion flip-flops
	--
	process(in_clk_insert) begin
		if rising_edge(in_clk_insert) then
			if in_rst = '1' then
				state_fp <= WaitFPCommand;
				fp <= (others => '0');
			else
				state_fp <= next_state_fp;
				fp <= next_fp;
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

				-- increment front pointer
				next_fp <= inc_logvec(fp, 1);

				next_state_fp <= WaitFPCommand;
		end case;
	end process;
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	--
	-- back-pointer / element removal flip-flops
	--
	process(in_clk_remove) begin
		if rising_edge(in_clk_remove) then
			if in_rst = '1' then
				state_bp <= WaitBPCommand;
				bp <= (others => '0');
			else
				state_bp <= next_state_bp;
				bp <= next_bp;
			end if;
		end if;
	end process;


	--
	-- back-pointer / element removal state combinatorics
	--
	process(state_bp, bp, empty, in_remove) begin
		next_state_bp <= state_bp;
		next_bp <= bp;

		out_ready_to_remove <= '0';

		--report "*** FIFO: state_bp = " & t_state_bp'image(state_bp)
		--	& ", bp = 0x" & to_hstring(bp)
		--	& ", data = 0x" & to_hstring(words(to_int(bp)));

		case state_bp is
			when WaitBPCommand =>
				if in_remove = '1' then
					next_state_bp <= Remove;
				else
					out_ready_to_remove <= '1';
				end if;

			when Remove =>
				next_state_bp <= WaitBPCommand;
			
				-- only remove element if the buffer is not empty
				if empty = '0' then
					-- remove an element at the back: increment back pointer
					next_bp <= inc_logvec(bp, 1);
				end if;
		end case;
	end process;
	-----------------------------------------------------------------------

end architecture;



--
-- direct implementation without checks or (waiting) states
--
architecture fifo_direct of fifo is
	-- buffer memory size
	constant NUM_WORDS : natural := 2**ADDR_BITS;

	-- word type
	subtype t_word is std_logic_vector(WORD_BITS - 1 downto 0);
	type t_words is array(0 to NUM_WORDS - 1) of t_word;

	-- buffer memory
	signal words : t_words := (others => (others => '0'));

	-- front and back pointers
	signal fp, next_fp : std_logic_vector(ADDR_BITS - 1 downto 0) := (others => '0');
	signal bp, next_bp : std_logic_vector(ADDR_BITS - 1 downto 0) := (others => '0');

	signal empty : std_logic := '1';

begin

	-- output data at back pointer
	out_back <= words(to_int(bp));

	-- buffer empty?
	empty <= '1' when to_int(bp) = to_int(fp) else '0';
	out_empty <= empty;

	out_ready_to_insert <= '1';
	out_ready_to_remove <= '1';


	-----------------------------------------------------------------------
	--
	-- front-pointer / element insertion flip-flops
	--
	process(in_clk_insert) begin
		if rising_edge(in_clk_insert) then
			if in_rst = '1' then
				fp <= (others => '0');
			else
				fp <= next_fp;
			end if;
		end if;
	end process;


	--
	-- front-pointer / element insertion combinatorics
	--
	process(fp, in_insert, in_data) begin
		next_fp <= fp;

		--report "*** FIFO: "
		--	& "fp = 0x" & to_hstring(fp)
		--	& ", data = 0x" & to_hstring(in_data);

		if in_insert = '1' then
			-- write data to front pointer
			words(to_int(fp)) <= in_data;

			-- increment front pointer
			next_fp <= inc_logvec(fp, 1);
		end if;
	end process;
	-----------------------------------------------------------------------


	-----------------------------------------------------------------------
	--
	-- back-pointer / element removal flip-flops
	--
	process(in_clk_remove) begin
		if rising_edge(in_clk_remove) then
			if in_rst = '1' then
				bp <= (others => '0');
			else
				bp <= next_bp;
			end if;
		end if;
	end process;


	--
	-- back-pointer / element removal combinatorics
	--
	process(bp, in_remove, empty) begin
		next_bp <= bp;

		--report "*** FIFO: "
		--	& "bp = 0x" & to_hstring(bp)
		--	& ", empty = " & std_logic'image(empty)
		--	& ", data = 0x" & to_hstring(words(to_int(bp)));

		if in_remove = '1' and empty = '0' then
			-- increment back pointer
			next_bp <= inc_logvec(bp, 1);
		end if;
	end process;
	-----------------------------------------------------------------------

end architecture;
