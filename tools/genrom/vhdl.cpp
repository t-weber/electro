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
	bool direct_ports, bool fill_rom, bool print_chars, const std::string& module_name)
{
	// rom file
	std::string rom_vhdl = R"raw(library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;

entity %%MODULE_NAME%% is
	generic(
		constant NUM_PORTS : natural := %%NUM_PORTS%%;
		constant ADDR_BITS : natural := %%ADDR_BITS%%;
		constant WORD_BITS : natural := %%WORD_BITS%%;
		constant NUM_WORDS : natural := %%NUM_WORDS%%
	);

	port(%%PORTS_DEF%%);
end entity;

architecture %%MODULE_NAME%%_impl of %%MODULE_NAME%% is
	subtype t_word is std_logic_vector(WORD_BITS-1 downto 0);
	type t_words is array(0 to NUM_WORDS-1) of t_word;

	constant words : t_words :=
	(
%%ROM_DATA%%
	);

begin
%%PORTS_ASSIGN%%

end architecture;)raw";

	// rom generic port definitions
	std::string rom_ports_vhdl = R"raw(
		in_addr  : in  t_logicvecarray(0 to NUM_PORTS-1)(ADDR_BITS-1 downto 0);
		out_data : out t_logicvecarray(0 to NUM_PORTS-1)(WORD_BITS-1 downto 0)
	)raw";

	// rom generic port assignment
	std::string rom_ports_assign_vhdl = R"raw(
	gen_ports : for portidx in 0 to NUM_PORTS-1 generate
	begin
		out_data(portidx) <= words(to_int(in_addr(portidx)));
	end generate;)raw";


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
	boost::replace_all(rom_vhdl, "%%MODULE_NAME%%", module_name);
	if(fill_rom)
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_vhdl, "%%NUM_PORTS%%", std::to_string(num_ports));
	boost::replace_all(rom_vhdl, "%%WORD_BITS%%", std::to_string(word_bits));
	boost::replace_all(rom_vhdl, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_vhdl, "%%ROM_DATA%%", ostr_data.str());

	if(direct_ports && num_ports == 1)
	{
		// only one port

		std::ostringstream ostrPorts;

		ostrPorts << "\n";
		ostrPorts << "\t\tin_addr  : in  std_logic_vector(ADDR_BITS-1 downto 0);\n";
		ostrPorts << "\t\tout_data : out std_logic_vector(WORD_BITS-1 downto 0)\n";
		ostrPorts << "\t";

		boost::replace_all(rom_vhdl, "%%PORTS_DEF%%", ostrPorts.str());
		boost::replace_all(rom_vhdl, "%%PORTS_ASSIGN%%", "\tout_data <= words(to_int(in_addr));");
	}
	else if(direct_ports && num_ports > 1)
	{
		// iterate ports directly
		std::ostringstream ostrPorts, ostrAssign;

		ostrPorts << "\n";
		for(int port = 0; port < num_ports; ++port)
		{
			ostrPorts << "\t\tin_addr_" << (port+1) << "  : in  std_logic_vector(ADDR_BITS-1 downto 0);\n";
			ostrPorts << "\t\tout_data_" << (port+1) << " : out std_logic_vector(WORD_BITS-1 downto 0)";

			ostrAssign << "\tout_data_" << (port+1) << " <= words(to_int(in_addr_" << (port+1)<< "));";

			if(port + 1 < num_ports)
			{
				ostrPorts << ";";
				ostrAssign << "\n";
			}
			ostrPorts << "\n\n";
		}
		ostrPorts << "\t";

		boost::replace_all(rom_vhdl, "%%PORTS_DEF%%", ostrPorts.str());
		boost::replace_all(rom_vhdl, "%%PORTS_ASSIGN%%", ostrAssign.str());
	}
	else
	{
		// generate generic ports array
		boost::replace_all(rom_vhdl, "%%PORTS_DEF%%", rom_ports_vhdl);
		boost::replace_all(rom_vhdl, "%%PORTS_ASSIGN%%", rom_ports_assign_vhdl);
	}

	return rom_vhdl;
}
