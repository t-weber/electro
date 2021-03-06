--
-- conversions
-- @author Tobias Weber <tobias.weber@tum.de>
-- @date dec-2020
-- @license see 'LICENSE' file
--

library ieee;
use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;



package conv is
	-- array types
	type t_logicarray is array(natural range <>) of std_logic;
	type t_logicvecarray is array(natural range <>) of std_logic_vector;

	-- std_logic_vector -> integer
	pure function to_int(vec : std_logic_vector) return integer;

	-- integer/natural -> std_logic_vector
	pure function int_to_logvec(val : integer; len : natural) return std_logic_vector;
	pure function nat_to_logvec(val : natural; len : natural) return std_logic_vector;

	-- increments a std_logic_vector
	pure function inc_logvec(vec : std_logic_vector; inc : natural) return std_logic_vector;
end package;



package body conv is
	--
	-- std_logic_vector -> integer
	--
	pure function to_int(vec : std_logic_vector) return integer is
	begin
		return to_integer(unsigned(vec));
	end function;


	--
	-- integer -> std_logic_vector
	--
	pure function int_to_logvec(val : integer; len : natural) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(val, len));
	end function;


	--
	-- natural -> std_logic_vector
	--
	pure function nat_to_logvec(val : natural; len : natural) return std_logic_vector is
	begin
		return std_logic_vector(to_unsigned(val, len));
	end function;


	--
	-- increments a std_logic_vector by inc
	--
	pure function inc_logvec(vec : std_logic_vector; inc : natural) return std_logic_vector is
	begin
		return std_logic_vector(unsigned(vec) + inc);
	end function;
end package body;
