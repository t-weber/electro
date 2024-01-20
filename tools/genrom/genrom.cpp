/**
 * generates rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

// g++ -Wall -Wextra -Weffc++ -std=c++20 -lboost_program_options -o genrom genrom.cpp

#include <string>
#include <iomanip>
#include <iostream>
#include <fstream>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>
#include <boost/program_options.hpp>

namespace args = boost::program_options;



/**
 * generates a vhdl rom file
 */
std::string gen_rom_vhdl(std::istream& data, int max_line_len = 16,
	int num_ports = 2, bool fill_rom = true)
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
		out_word : out t_logicvecarray(0 to NUM_PORTS-1)(WORDBITS-1 downto 0)
	);
end entity;

architecture rom_impl of rom is
	subtype t_word is std_logic_vector(WORDBITS-1 downto 0);
	type t_words is array(0 to NUM_WORDS-1) of t_word;

	signal words : t_words :=
	(
%%ROM_DATA%%
	);

begin
	gen_ports : for portidx in 0 to NUM_PORTS-1 generate
	begin
		out_word(portidx) <= words(to_int(in_addr(portidx)));
	end generate;

end architecture;)raw";


	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;

	std::ostringstream ostr_data;
	ostr_data << "\t\t";
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
			ostr_data << "\n\t\t";
			cur_line_len = 0;
		}

		ostr_data
			<< "x\""
			<< std::hex << std::setfill('0') << std::setw(2)
			<< static_cast<unsigned int>(ch)
			<< "\"";
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
				ostr_data << "\n\t\t";
				cur_line_len = 0;
			}

			ostr_data
				<< "x\""
				<< std::hex << std::setfill('0') << std::setw(2)
				<< fill_data
				<< "\"";
			first_data = false;

			++cur_line_len;
		}
	}

	// fill in missing rom data fields
	if(fill_rom)
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_vhdl, "%%NUM_PORTS%%", std::to_string(num_ports));
	boost::replace_all(rom_vhdl, "%%WORD_BITS%%", std::to_string(8));
	boost::replace_all(rom_vhdl, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_vhdl, "%%ROM_DATA%%", ostr_data.str());

	return rom_vhdl;
}



/**
 * generates an SV rom file
 */
std::string gen_rom_sv(std::istream& data, int max_line_len = 16,
	int num_ports = 2, bool fill_rom = true)
{
	// TODO

	// rom file
	std::string rom_sv = R"raw(module rom
#(
	parameter NUM_PORTS = %%NUM_PORTS%%,
	parameter ADDRBITS  = %%ADDR_BITS%%,
	parameter WORDBITS  = %%WORD_BITS%%,
	parameter NUM_WORDS = %%NUM_WORDS%%
)
(
	input wire[ADDRBITS-1 : 0] in_addr,
	output wire[WORDBITS-1 : 0] out_word
);

logic [WORDBITS-1 : 0] words[NUM_WORDS] =
{
%%ROM_DATA%%
};

assign out_word = words[in_addr];

endmodule)raw";


	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;

	std::ostringstream ostr_data;
	ostr_data << "\t\t";
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
			ostr_data << "\n\t\t";
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
				ostr_data << "\n\t\t";
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



int main(int argc, char** argv)
{
	std::string in_data, out_rom;
	std::string rom_type = "vhdl";
	int line_len = 16;
	bool fill_rom = true;
	int num_ports = 2;

	args::options_description arg_descr("ROM generator arguments");
	arg_descr.add_options()
		("linelen,l", args::value<decltype(line_len)>(&line_len),
			("line length, default: " + std::to_string(line_len)).c_str())
		("fill,f", args::value<bool>(&fill_rom),
			("fill non-used rom fields with zeros, default: " + std::to_string(fill_rom)).c_str())
		("type,t", args::value<decltype(rom_type)>(&rom_type),
			("output rom type (vhdl/sv), default: " + rom_type).c_str())
		("ports,p", args::value<decltype(num_ports)>(&num_ports),
			("number of memory ports, default: " + std::to_string(num_ports)).c_str())
		("input,i", args::value<decltype(in_data)>(&in_data),
			"input data file")
		("output,o", args::value<decltype(in_data)>(&out_rom),
			"output rom file");

	args::positional_options_description posarg_descr;
	posarg_descr.add("input", -1);

	auto argparser = args::command_line_parser{argc, argv};
	argparser.style(args::command_line_style::default_style);
	argparser.options(arg_descr);
	argparser.positional(posarg_descr);

	args::variables_map mapArgs;
	auto parsedArgs = argparser.run();
	args::store(parsedArgs, mapArgs);
	args::notify(mapArgs);

	if(in_data == "")
	{
		std::cout << arg_descr << std::endl;
		return -1;
	}

	// input file
	std::ifstream ifstr(in_data);
	if(!ifstr)
	{
		std::cerr << "Cannot open input " << in_data << "." << std::endl;
		return -1;
	}

	// output file
	std::ostream *postr = &std::cout;
	std::ofstream ofstr(out_rom);

	if(out_rom != "")
	{
		if(!ofstr)
		{
			std::cerr << "Cannot open output " << out_rom << "." << std::endl;
			return -1;
		}

		postr = &ofstr;
	}

	// set rom generator function
	std::string (*gen_rom_fkt)(std::istream&, int, int, bool) = &gen_rom_vhdl;
	if(rom_type == "vhdl")
		gen_rom_fkt = &gen_rom_vhdl;
	else if(rom_type == "sv")
		gen_rom_fkt = &gen_rom_sv;

	// generate rom
	(*postr) << (*gen_rom_fkt)(ifstr, line_len, num_ports, fill_rom) << std::endl;

	return 0;
}
