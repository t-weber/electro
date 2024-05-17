/**
 * generates .v rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include "v.h"

#include <string>
#include <iomanip>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates a .v rom
 */
std::string gen_rom_v(const t_words& data, int max_line_len, int num_ports,
	bool direct_ports, bool fill_rom, bool print_chars, bool check_bounds,
	const std::string& module_name)
{
	// rom file
	std::string rom_v = R"raw(module %%MODULE_NAME%%
#(
	parameter NUM_PORTS = %%NUM_PORTS%%,
	parameter ADDR_BITS = %%ADDR_BITS%%,
	parameter WORD_BITS = %%WORD_BITS%%,
	parameter NUM_WORDS = %%NUM_WORDS%%,
	parameter LINE_LEN  = %%LINE_LEN%%
)
(%%PORTS_DEF%%);

wire [WORD_BITS-1 : 0] words [0 : NUM_WORDS - 1];

%%ROM_DATA%%

%%PORTS_ASSIGN%%
endmodule)raw";

	// rom generic port definitions
	std::string rom_ports_v = R"raw(
	input  wire[NUM_PORTS][ADDR_BITS-1 : 0] in_addr,
	output wire[NUM_PORTS][WORD_BITS-1 : 0] out_data
)raw";

	// rom generic port assignment
	std::string rom_ports_assign_v;
        if(check_bounds)
        {
		rom_ports_assign_v = R"raw(
genvar port_idx;
generate for(port_idx=0; port_idx<NUM_PORTS; ++port_idx)
begin : gen_ports
	assign out_data[port_idx] = in_addr[port_idx] < NUM_WORDS
		? words[in_addr[port_idx]]
		: WORD_BITS'(1'b0);
end
endgenerate
)raw";
        }
	else
	{
		rom_ports_assign_v = R"raw(
genvar port_idx;
generate for(port_idx=0; port_idx<NUM_PORTS; ++port_idx)
begin : gen_ports
	assign out_data[port_idx] = words[in_addr[port_idx]];
end
endgenerate
)raw";
	}


	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;
	int cur_line = 0;

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
			ostr_data << "// ";
			for(char c : chs)
				ostr_data << c;
			ostr_data << "\n";

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
			++cur_line;
		}

		ostr_data << std::setfill(' ') << std::dec << "assign words [ "
			<< std::setw(3) << cur_line << "*LINE_LEN + "
			<< std::setw(3) << cur_line_len << " ] = ";

		if(word_bits % 4 == 0)
		{
			// print as hex
			ostr_data
				//<< "WORD_BITS'('h"
				<< "%%WORD_BITS%%'h"
				<< std::hex << std::setfill('0') << std::setw(word_bits/4)
				<< dat.to_ulong();
				//<< ")";
		}
		else
		{
			// print as binary
			ostr_data
				//<< "WORD_BITS'('b"
				<< "%%WORD_BITS%%'b"
				<< dat;
				//<< ")";
		}

		ostr_data << ";\n";

		if(print_chars)
			add_char(static_cast<int>(dat.to_ulong()));

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
			if(cur_line_len >= max_line_len)
			{
				if(print_chars)
					write_chars();

				ostr_data << "\n\t";
				cur_line_len = 0;
				++cur_line;
			}

			ostr_data << std::setfill(' ') << std::dec << "assign words [ "
				<< std::setw(3) << cur_line << "*LINE_LEN + "
				<< std::setw(3) << cur_line_len << " ] = ";

			if(word_bits % 4 == 0)
			{
				// print as hex
				ostr_data
					//<< "WORD_BITS'('h"
					<< "%%WORD_BITS%%'h"
					<< std::hex << std::setfill('0') << std::setw(word_bits/4)
					<< fill_data.to_ulong();
					//<< ")";
			}
			else
			{
				// print as binary
				ostr_data
					//<< "WORD_BITS'('b"
					<< "%%WORD_BITS%%'b"
					<< fill_data;
					//<< ")";
			}

			ostr_data << ";\n";

			++cur_line_len;
		}
	}

	if(print_chars)
		write_chars();

	// fill in missing rom data fields
	boost::replace_all(rom_v, "%%MODULE_NAME%%", module_name);
	if(fill_rom)
		boost::replace_all(rom_v, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_v, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_v, "%%ROM_DATA%%", ostr_data.str());
	boost::replace_all(rom_v, "%%WORD_BITS%%", std::to_string(word_bits));
	boost::replace_all(rom_v, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_v, "%%NUM_PORTS%%", std::to_string(num_ports));
	boost::replace_all(rom_v, "%%LINE_LEN%%", std::to_string(max_line_len));

	if(direct_ports && num_ports == 1)
	{
		// only one port

		std::ostringstream ostrPorts;

		ostrPorts << "\n";
		ostrPorts << "\tinput  wire[ADDR_BITS-1 : 0] in_addr,\n";
		ostrPorts << "\toutput wire[WORD_BITS-1 : 0] out_data\n";

		boost::replace_all(rom_v, "%%PORTS_DEF%%", ostrPorts.str());
		boost::replace_all(rom_v, "%%PORTS_ASSIGN%%",
			check_bounds ? "assign out_data = in_addr < NUM_WORDS ? words[in_addr] : WORD_BITS'(1'b0);\n"
			             : "assign out_data = words[in_addr];\n");

	}
	else if(direct_ports && num_ports > 1)
	{
		// iterate ports directly
		std::ostringstream ostrPorts, ostrAssign;

		ostrPorts << "\n";
		for(int port = 0; port < num_ports; ++port)
		{
			ostrPorts << "\tinput  wire[ADDR_BITS-1 : 0] in_addr_" << (port+1) << ",\n";
			ostrPorts << "\toutput wire[WORD_BITS-1 : 0] out_data_" << (port+1);

			if(check_bounds)
			{
				ostrAssign << "assign out_data_" << (port+1)
					<< " = in_addr_" << (port+1) << " < NUM_WORDS\n"
					<< "\t? words[in_addr_" << (port+1) << "]\n"
					<< "\t: WORD_BITS'(1'b0);\n";
                        }
			else
			{
				ostrAssign << "assign out_data_" << (port+1)
					<< " = words[in_addr_" << (port+1) << "];";
			}

			if(port + 1 < num_ports)
			{
				ostrPorts << ",";
				ostrAssign << "\n";
			}
			ostrPorts << "\n\n";
		}
		ostrAssign << "\n";

		boost::replace_all(rom_v, "%%PORTS_DEF%%", ostrPorts.str());
		boost::replace_all(rom_v, "%%PORTS_ASSIGN%%", ostrAssign.str());
	}
	else
	{
		// generate generic ports array
		boost::replace_all(rom_v, "%%PORTS_DEF%%", rom_ports_v);
		boost::replace_all(rom_v, "%%PORTS_ASSIGN%%", rom_ports_assign_v);
	}

	return rom_v;
}
