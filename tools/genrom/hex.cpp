/**
 * generates a hex dump
 * @author Tobias Weber
 * @date 3-Feb-2024
 * @license see 'LICENSE' file
 */

#include "hex.h"

#include <string>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates a hex dump
 */
std::string gen_rom_hex(std::istream& data, int max_line_len,
	[[__maybe_unused__]] int num_ports,
	bool fill_rom, bool print_chars)
{
	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;

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

	while(!!data)
	{
		int ch = data.get();
		if(ch == std::istream::traits_type::eof())
			break;

		if(cur_line_len >= max_line_len)
		{
			if(print_chars)
				write_chars();

			ostr_data << "\n";
			cur_line_len = 0;
		}

		ostr_data
			<< std::hex << std::setfill('0') << std::setw(2)
			<< static_cast<unsigned int>(ch)
			<< " ";

		if(print_chars)
			add_char(ch);

		++rom_len;
		++cur_line_len;
	}

	std::size_t addr_bits = std::size_t(std::ceil(std::log2(double(rom_len))));

	// fill-up data block to maximum size
	if(fill_rom)
	{
		std::size_t max_rom_len = std::pow(2, addr_bits);

		unsigned int fill_data = 0x00;
		for(; rom_len < max_rom_len; ++rom_len)
		{
			if(cur_line_len >= max_line_len)
			{
				if(print_chars)
					write_chars();

				ostr_data << "\n";
				cur_line_len = 0;
			}

			ostr_data
				<< std::hex << std::setfill('0') << std::setw(2)
				<< fill_data
				<< " ";

			++cur_line_len;
		}
	}

	if(print_chars)
		write_chars();

	return ostr_data.str();
}
