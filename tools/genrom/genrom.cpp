/**
 * generates rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

// g++ -Wall -Wextra -Weffc++ -std=c++20 -lboost_program_options -o genrom genrom.cpp vhdl.cpp sv.cpp

#include <iostream>
#include <fstream>

#include <boost/program_options.hpp>
namespace args = boost::program_options;

#include "vhdl.h"
#include "sv.h"


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
