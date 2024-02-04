/**
 * generates sv rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include "sv.h"

#include <string>
#include <iomanip>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates an SV rom
 */
std::string gen_rom_sv(const t_words& data, int max_line_len, int num_ports,
	bool fill_rom, bool print_chars)
{
	// rom file
	std::string rom_sv = R"raw(module rom
#(
	parameter NUM_PORTS = %%NUM_PORTS%%,
	parameter ADDRBITS  = %%ADDR_BITS%%,
	parameter WORDBITS  = %%WORD_BITS%%,
	parameter NUM_WORDS = %%NUM_WORDS%%
)
(
	input  wire[NUM_PORTS][ADDRBITS-1 : 0] in_addr,
	output wire[NUM_PORTS][WORDBITS-1 : 0] out_data
);

logic [NUM_WORDS][WORDBITS-1 : 0] words =
{
%%ROM_DATA%%
};

genvar port_idx;
generate for(port_idx=0; port_idx<NUM_PORTS; ++port_idx)
begin : gen_ports
	assign out_data[port_idx] = words[in_addr[port_idx]];
end
endgenerate

endmodule)raw";


	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;

	// get word size
	typename t_word::size_type word_bits = 8;
	if(data.size())
		word_bits = data[0].size();

	std::ostringstream ostr_data;
	ostr_data << "\t";
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
			ostr_data << " // ";
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

			ostr_data << "\n\t";
			cur_line_len = 0;
		}

		if(word_bits % 4 == 0)
		{
			// print as hex
			ostr_data
				//<< "WORDBITS'('h"
				<< "%%WORD_BITS%%'h"
				<< std::hex << std::setfill('0') << std::setw(word_bits/4)
				<< dat.to_ulong() /*<< ")"*/;
		}
		else
		{
			// print as binary
			ostr_data
				//<< "WORDBITS'('h"
				<< "%%WORD_BITS%%'b"
				<< dat /*<< ")"*/;
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

				ostr_data << "\n\t";
				cur_line_len = 0;
			}

			if(word_bits % 4 == 0)
			{
				// print as hex
				ostr_data
					//<< "WORDBITS'('h"
					<< "%%WORD_BITS%%'h"
					<< std::hex << std::setfill('0') << std::setw(word_bits/4)
					<< fill_data.to_ulong() /*<< ")"*/;
			}
			else
			{
				// print as binary
				ostr_data
					//<< "WORDBITS'('h"
					<< "%%WORD_BITS%%'b"
					<< fill_data /*<< ")"*/;
			}

			first_data = false;
			++cur_line_len;
		}
	}

	if(print_chars)
		write_chars();

	// fill in missing rom data fields
	if(fill_rom)
		boost::replace_all(rom_sv, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_sv, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_sv, "%%ROM_DATA%%", ostr_data.str());
	boost::replace_all(rom_sv, "%%WORD_BITS%%", std::to_string(word_bits));
	boost::replace_all(rom_sv, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_sv, "%%NUM_PORTS%%", std::to_string(num_ports));

	return rom_sv;
}
