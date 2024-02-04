/**
 * generates vhdl rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include "vhdl.h"

#include <string>
#include <iomanip>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates a vhdl rom
 */
std::string gen_rom_vhdl(const t_words& data, int max_line_len, int num_ports,
	bool fill_rom, bool print_chars)
{
	// rom file
	std::string rom_vhdl = R"raw(library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;

entity rom is
	generic(
		constant NUM_PORTS : natural := %%NUM_PORTS%%;
		constant ADDRBITS  : natural := %%ADDR_BITS%%;
		constant WORDBITS  : natural := %%WORD_BITS%%;
		constant NUM_WORDS : natural := %%NUM_WORDS%%
	);

	port(
		in_addr  : in  t_logicvecarray(0 to NUM_PORTS-1)(ADDRBITS-1 downto 0);
		out_data : out t_logicvecarray(0 to NUM_PORTS-1)(WORDBITS-1 downto 0)
	);
end entity;

architecture rom_impl of rom is
	subtype t_word is std_logic_vector(WORDBITS-1 downto 0);
	type t_words is array(0 to NUM_WORDS-1) of t_word;

	constant words : t_words :=
	(
%%ROM_DATA%%
	);

begin
	gen_ports : for portidx in 0 to NUM_PORTS-1 generate
	begin
		out_data(portidx) <= words(to_int(in_addr(portidx)));
	end generate;

end architecture;)raw";


	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;

	// get word size
	typename t_word::size_type word_bits = 8;
	if(data.size())
		word_bits = data[0].size();

	std::ostringstream ostr_data;
	ostr_data << "\t\t";
	bool first_data = true;
	std::vector<char> chs;
	bool has_printables = false;

	// add a printable character to the comment
	auto add_char = [&chs, &has_printables](int ch)
	{
		if(std::isprint(ch))
		{
			chs.push_back(static_cast<char>(ch));
			has_printables = true;
		}
		else if(std::isspace(ch))
		{
			chs.push_back(' ');
		}
		else
		{
			chs.push_back('.');
		}
	};

	// print characters in a comment
	auto write_chars = [&chs, &has_printables, &ostr_data]()
	{
		if(has_printables)
		{
			ostr_data << " -- ";
			for(char c : chs)
				ostr_data << c;

			has_printables = false;
		}

		chs.clear();
	};

	for(const t_word& dat : data)
	{
		if(!first_data)
			ostr_data << ", ";

		if(cur_line_len >= max_line_len)
		{
			if(print_chars)
				write_chars();

			ostr_data << "\n\t\t";
			cur_line_len = 0;
		}

		if(word_bits % 4 == 0)
		{
			// print as hex
			ostr_data
				<< "x\""
				<< std::hex << std::setfill('0') << std::setw(word_bits/4)
				<< dat.to_ulong()
				<< "\"";
		}
		else
		{
			// print as binary
			ostr_data << "\"" << dat << "\"";
		}

		if(print_chars)
			add_char(static_cast<int>(dat.to_ulong()));

		first_data = false;
		++rom_len;
		++cur_line_len;
	}

	std::size_t addr_bits = rom_len > 0 ? std::size_t(std::ceil(std::log2(double(rom_len)))) : 0;

	// fill-up data block to maximum size
	if(fill_rom && rom_len > 0)
	{
		std::size_t max_rom_len = std::pow(2, addr_bits);

		t_word fill_data(word_bits, 0x00);
		for(; rom_len < max_rom_len; ++rom_len)
		{
			if(!first_data)
				ostr_data << ", ";

			if(cur_line_len >= max_line_len)
			{
				if(print_chars)
					write_chars();

				ostr_data << "\n\t\t";
				cur_line_len = 0;
			}

			if(word_bits % 4 == 0)
			{
				// print as hex
				ostr_data
					<< "x\""
					<< std::hex << std::setfill('0') << std::setw(word_bits/4)
					<< fill_data.to_ulong()
					<< "\"";
			}
			else
			{
				// print as binary
				ostr_data << "\"" << fill_data << "\"";
			}

			first_data = false;
			++cur_line_len;
		}
	}

	if(print_chars)
		write_chars();

	// fill in missing rom data fields
	if(fill_rom)
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_vhdl, "%%NUM_PORTS%%", std::to_string(num_ports));
	boost::replace_all(rom_vhdl, "%%WORD_BITS%%", std::to_string(word_bits));
	boost::replace_all(rom_vhdl, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_vhdl, "%%ROM_DATA%%", ostr_data.str());

	return rom_vhdl;
}
