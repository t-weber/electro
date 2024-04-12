/**
 * generates a hex dump
 * @author Tobias Weber
 * @date 3-Feb-2024
 * @license see 'LICENSE' file
 */

#include "hex.h"

#include <string>
#include <iomanip>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates a hex or binary dump
 */
std::string gen_rom_hex(const t_words& data, int max_line_len,
	[[__maybe_unused__]] int num_ports, [[__maybe_unused__]] bool direct_ports,
	bool fill_rom, bool print_chars, [[__maybe_unused__]] const std::string& module_name)
{
	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;

	// get word size
	typename t_word::size_type word_bits = 8;
	if(data.size())
		word_bits = data[0].size();

	std::ostringstream ostr_data;
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
			ostr_data << " |";
			for(char c : chs)
				ostr_data << c;
			ostr_data << "|";

			has_printables = false;
		}

		chs.clear();
	};

	for(const t_word& dat : data)
	{
		if(cur_line_len >= max_line_len)
		{
			if(print_chars)
				write_chars();

			ostr_data << "\n";
			cur_line_len = 0;
		}

		if(word_bits % 4 == 0)
		{
			// print as hex
			ostr_data
				<< std::hex << std::setfill('0') << std::setw(word_bits/4)
				<< dat.to_ulong()
				<< " ";
		}
		else
		{
			// print as binary
			ostr_data << dat << " ";
		}

		if(print_chars)
			add_char(static_cast<int>(dat.to_ulong()));

		++rom_len;
		++cur_line_len;
	}

	// fill-up data block to maximum size
	if(fill_rom && rom_len > 0)
	{
		std::size_t addr_bits = std::size_t(std::ceil(std::log2(double(rom_len))));
		std::size_t max_rom_len = std::pow(2, addr_bits);

		t_word fill_data(word_bits, 0x00);
		for(; rom_len < max_rom_len; ++rom_len)
		{
			if(cur_line_len >= max_line_len)
			{
				if(print_chars)
					write_chars();

				ostr_data << "\n";
				cur_line_len = 0;
			}

			if(word_bits % 4 == 0)
			{
				// print as hex
				ostr_data
					<< std::hex << std::setfill('0') << std::setw(word_bits/4)
					<< fill_data.to_ulong()
					<< " ";
			}
			else
			{
				// print as binary
				ostr_data << fill_data << " ";
			}

			++cur_line_len;
		}
	}

	if(print_chars)
		write_chars();

	return ostr_data.str();
}
