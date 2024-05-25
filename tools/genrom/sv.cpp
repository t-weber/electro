/**
 * generates sv rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include "sv.h"
#include "common.h"

#include <string>
#include <iomanip>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates an SV rom
 */
std::string gen_rom_sv(const Config& cfg)
{
	// rom file
	std::string rom_sv = R"raw(module %%MODULE_NAME%%
#(
	parameter NUM_PORTS = %%NUM_PORTS%%,
	parameter NUM_WORDS = %%NUM_WORDS%%,
	parameter ADDR_BITS = %%ADDR_BITS%% /*$clog2(NUM_WORDS)*/,
	parameter WORD_BITS = %%WORD_BITS%%
)
(%%PORTS_DEF%%);

logic [0 : NUM_WORDS - 1][WORD_BITS - 1 : 0] words =
{
%%ROM_DATA%%
};

%%PORTS_ASSIGN%%
endmodule)raw";


	// create data block
	std::size_t rom_len = 0;
	std::size_t cur_line_len = 0;

	// get word size
	typename t_word::size_type word_bits = 8;
	if(cfg.data.size())
		word_bits = cfg.data[0].size();

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

	for(const t_word& dat : cfg.data)
	{
		if(!first_data)
			ostr_data << ", ";

		if(cur_line_len >= cfg.max_line_len)
		{
			if(cfg.print_chars)
				write_chars();

			ostr_data << "\n\t";
			cur_line_len = 0;
		}

		if(word_bits % 4 == 0)
		{
			// print as hex
			ostr_data
				//<< "WORD_BITS'('h"
				<< "%%WORD_BITS%%'h"
				<< std::hex << std::setfill('0') << std::setw(word_bits/4)
				<< dat.to_ulong() /*<< ")"*/;
		}
		else
		{
			// print as binary
			ostr_data
				//<< "WORD_BITS'('b"
				<< "%%WORD_BITS%%'b"
				<< dat /*<< ")"*/;
		}

		if(cfg.print_chars)
			add_char(static_cast<int>(dat.to_ulong()));

		first_data = false;
		++rom_len;
		++cur_line_len;
	}

	const std::size_t addr_bits = rom_len > 0
		? std::size_t(std::ceil(std::log2(double(rom_len))))
		: 0;

	const std::size_t max_rom_len = std::pow(2, addr_bits);

	// fill-up data block to maximum size
	if(cfg.fill_rom && rom_len > 0)
	{
		t_word fill_data(word_bits, 0x00);
		for(; rom_len < max_rom_len; ++rom_len)
		{
			if(!first_data)
				ostr_data << ", ";

			if(cur_line_len >= cfg.max_line_len)
			{
				if(cfg.print_chars)
					write_chars();

				ostr_data << "\n\t";
				cur_line_len = 0;
			}

			if(word_bits % 4 == 0)
			{
				// print as hex
				ostr_data
					//<< "WORD_BITS'('h"
					<< "%%WORD_BITS%%'h"
					<< std::hex << std::setfill('0') << std::setw(word_bits/4)
					<< fill_data.to_ulong() /*<< ")"*/;
			}
			else
			{
				// print as binary
				ostr_data
					//<< "WORD_BITS'('b"
					<< "%%WORD_BITS%%'b"
					<< fill_data /*<< ")"*/;
			}

			first_data = false;
			++cur_line_len;
		}
	}

	bool check_bounds = cfg.check_bounds;
	test_bounds_check(rom_len, max_rom_len, check_bounds);

	if(cfg.print_chars)
		write_chars();

	// fill in missing rom data fields
	boost::replace_all(rom_sv, "%%MODULE_NAME%%", cfg.module_name);
	if(cfg.fill_rom)
		boost::replace_all(rom_sv, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_sv, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_sv, "%%ROM_DATA%%", ostr_data.str());
	boost::replace_all(rom_sv, "%%WORD_BITS%%", std::to_string(word_bits));
	boost::replace_all(rom_sv, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_sv, "%%NUM_PORTS%%", std::to_string(cfg.num_ports));

	if(cfg.direct_ports && cfg.num_ports == 1)
	{
		// only one port

		std::ostringstream ostrPorts;

		ostrPorts << "\n";
		ostrPorts << "\tinput  wire[ADDR_BITS - 1 : 0] in_addr,\n";
		ostrPorts << "\toutput wire[WORD_BITS - 1 : 0] out_data\n";

		boost::replace_all(rom_sv, "%%PORTS_DEF%%", ostrPorts.str());
		boost::replace_all(rom_sv, "%%PORTS_ASSIGN%%",
			check_bounds ? "assign out_data = in_addr < NUM_WORDS ? words[in_addr] : WORD_BITS'(1'b0);\n"
			             : "assign out_data = words[in_addr];\n");
	}
	else if(cfg.direct_ports && cfg.num_ports > 1)
	{
		// iterate ports directly
		std::ostringstream ostrPorts, ostrAssign;

		ostrPorts << "\n";
		for(std::size_t port = 0; port < cfg.num_ports; ++port)
		{
			ostrPorts << "\tinput  wire[ADDR_BITS - 1 : 0] in_addr_" << (port+1) << ",\n";
			ostrPorts << "\toutput wire[WORD_BITS - 1 : 0] out_data_" << (port+1);

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

			if(port + 1 < cfg.num_ports)
			{
				ostrPorts << ",";
				ostrAssign << "\n";
			}
			ostrPorts << "\n\n";
		}
		ostrAssign << "\n";

		boost::replace_all(rom_sv, "%%PORTS_DEF%%", ostrPorts.str());
		boost::replace_all(rom_sv, "%%PORTS_ASSIGN%%", ostrAssign.str());
	}
	else
	{
		// rom generic port definitions
		std::string rom_ports_sv = R"raw(
	input  wire[0 : NUM_PORTS - 1][ADDR_BITS - 1 : 0] in_addr,
	output wire[0 : NUM_PORTS - 1][WORD_BITS - 1 : 0] out_data
)raw";


		// rom generic port assignment
		std::string rom_ports_assign_sv;
		if(check_bounds)
		{
			rom_ports_assign_sv = R"raw(
genvar port_idx;
generate for(port_idx = 0; port_idx < NUM_PORTS; ++port_idx)
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
			rom_ports_assign_sv = R"raw(
genvar port_idx;
generate for(port_idx = 0; port_idx < NUM_PORTS; ++port_idx)
begin : gen_ports
	assign out_data[port_idx] = words[in_addr[port_idx]];
end
endgenerate
)raw";
		}


		// generate generic ports array
		boost::replace_all(rom_sv, "%%PORTS_DEF%%", rom_ports_sv);
		boost::replace_all(rom_sv, "%%PORTS_ASSIGN%%", rom_ports_assign_sv);
	}

	return rom_sv;
}
