/**
 * generates sv rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include "sv.h"

#include <string>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates an SV rom file
 */
std::string gen_rom_sv(std::istream& data, int max_line_len, int num_ports, bool fill_rom)
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

	std::ostringstream ostr_data;
	ostr_data << "\t";
	bool first_data = true;
	while(!!data)
	{
		int ch = data.get();
		if(ch == std::istream::traits_type::eof())
			break;

		if(!first_data)
			ostr_data << ", ";

		if(cur_line_len >= max_line_len)
		{
			ostr_data << "\n\t";
			cur_line_len = 0;
		}

		ostr_data
			<< "WORDBITS'('h"
			<< std::hex << std::setfill('0') << std::setw(2)
			<< static_cast<unsigned int>(ch)
			<< ")";
		first_data = false;

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
			if(!first_data)
				ostr_data << ", ";

			if(cur_line_len >= max_line_len)
			{
				ostr_data << "\n\t";
				cur_line_len = 0;
			}

			ostr_data
				<< "WORDBITS'('h"
				<< std::hex << std::setfill('0') << std::setw(2)
				<< fill_data
				<< ")";
			first_data = false;

			++cur_line_len;
		}
	}

	// fill in missing rom data fields
	if(fill_rom)
		boost::replace_all(rom_sv, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_sv, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_sv, "%%NUM_PORTS%%", std::to_string(num_ports));
	boost::replace_all(rom_sv, "%%WORD_BITS%%", std::to_string(8));
	boost::replace_all(rom_sv, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_sv, "%%ROM_DATA%%", ostr_data.str());

	return rom_sv;
}
