--
-- stack (lifo buffer)
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date 25-aug-2024
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;



entity stack is
	generic(
		constant ADDR_BITS : natural := 3;
		constant WORD_BITS : natural := 8
	);

	port(
		-- clock and reset
		in_clk, in_rst : in std_logic;

		-- ready to input command
		out_ready : out std_logic;

		-- 00 : nop
		-- 01 : push
		-- 10 : pop
		in_cmd : in std_logic_vector(1 downto 0);

		-- data to push
		in_data : in  std_logic_vector(WORD_BITS - 1 downto 0);

		-- data at the top of the stack
		out_top : out std_logic_vector(WORD_BITS - 1 downto 0)
	);
end entity;



architecture stack_impl of stack is
	constant NUM_WORDS : natural := 2**ADDR_BITS;

	subtype t_word is std_logic_vector(WORD_BITS - 1 downto 0);
	type t_words is array(0 to NUM_WORDS - 1) of t_word;

	-- stack memory
	signal words : t_words := (others => (others => '0'));

	-- input buffer
	signal data, next_data : t_word := (others => '0');

	-- stack pointer
	signal sp, next_sp : std_logic_vector(ADDR_BITS - 1 downto 0) := (others => '0');

	type t_state is (
		WaitCommand,
		Push, Push2,
		Pop
	);
	signal state, next_state : t_state := WaitCommand;

begin

	-- output data at stack pointer
	out_top <= words(to_int(sp));


	process(in_clk) begin
		if rising_edge(in_clk) then
			if in_rst = '1' then
				state <= WaitCommand;
				sp <= (others => '0');
				data <= (others => '0');
			else
				state <= next_state;
				sp <= next_sp;
				data <= next_data;
			end if;
		end if;
	end process;


	process(state, sp, data, in_cmd, in_data) begin
		next_state <= state;
		next_sp <= sp;
		next_data <= data;

		out_ready <= '0';

		--report "*** STACK: state = " & t_state'image(state)
		--	& ", sp = 0x" & to_hstring(sp)
		--	& ", cmd = 0b" & to_string(in_cmd)
		--	& ", data = 0x" & to_hstring(data);


		case state is
			when WaitCommand =>
				case in_cmd is
					when "01" =>
						next_state <= Push;
					when "10" =>
						next_state <= Pop;
					when others =>
						out_ready <= '1';
				end case;

			when Push =>
				-- decrement stack pointer
				next_sp <= dec_logvec(sp, 1);
				next_state <= Push2;

				-- buffer data
				next_data <= in_data;

			when Push2 =>
				-- write data to stack pointer
				words(to_int(sp)) <= data;
				next_state <= WaitCommand;

			when Pop =>
				-- increment stack pointer
				next_sp <= inc_logvec(sp, 1);
				next_state <= WaitCommand;
		end case;
	end process;

end architecture;
