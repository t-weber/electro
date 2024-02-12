/**
 * generates rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include <iostream>
#include <fstream>
#include <filesystem>

#include <boost/algorithm/string.hpp>
#include <boost/program_options.hpp>
namespace args = boost::program_options;

#include "defs.h"
#include "vhdl.h"
#include "sv.h"
#include "hex.h"
#include "img.h"


int main(int argc, char** argv)
{
	try
	{
		std::string in_filename, out_rom;
		std::string rom_type = "vhdl";
		int line_len = 16;
		int num_ports = 2;
		bool direct_ports = false;
		bool fill_rom = true;
		bool print_chars = true;

		args::options_description arg_descr("ROM generator arguments");
		arg_descr.add_options()
			("linelen,l", args::value<decltype(line_len)>(&line_len),
				("line length, default: "
					+ std::to_string(line_len)).c_str())
			("fill,f", args::value<bool>(&fill_rom),
				("fill non-used rom fields with zeros, default: "
					+ std::to_string(fill_rom)).c_str())
			("chars,c", args::value<bool>(&print_chars),
				("print characters, default: "
					+ std::to_string(print_chars)).c_str())
			("type,t", args::value<decltype(rom_type)>(&rom_type),
				("output rom type (vhdl/sv/hex), default: "
					+ rom_type).c_str())
			("ports,p", args::value<decltype(num_ports)>(&num_ports),
				("number of memory ports, default: "
					+ std::to_string(num_ports)).c_str())
			("directports,d", args::value<bool>(&direct_ports),
				("generate direct ports, default: "
					+ std::to_string(direct_ports)).c_str())
			("input,i", args::value<decltype(in_filename)>(&in_filename),
				"input data file")
			("output,o", args::value<decltype(out_rom)>(&out_rom),
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

		if(in_filename == "")
		{
			std::cerr << arg_descr << std::endl;
			return -1;
		}

		// input file
		std::filesystem::path in_file(in_filename);
		if(!std::filesystem::exists(in_file))
		{
			std::cerr << "Input file \"" << in_filename
				<< "\" does not exist." << std::endl;
			return -1;
		}

		std::ifstream ifstr(in_file);
		if(!ifstr)
		{
			std::cerr << "Cannot open input file \""
				<< in_filename << "\"." << std::endl;
			return -1;
		}

		// read input file
		t_words data;
		std::string ext = boost::to_lower_copy(in_file.extension().string());

		if(ext == ".png")
		{
			std::size_t w, h, ch;
			std::tie(w, h, ch, data) = read_png(in_file);
			std::cerr << "Read PNG image with size "
				<< w << " x " << h << " x " << ch << "." << std::endl;

			print_chars = false;
		}
		else if(ext == ".jpg" || ext == ".jpeg")
		{
			std::size_t w, h, ch;
			std::tie(w, h, ch, data) = read_jpg(in_file);
			std::cerr << "Read JPG image with size "
				<< w << " x " << h << " x " << ch << "." << std::endl;

			print_chars = false;
		}
		else  // read raw file
		{
			data.reserve(std::filesystem::file_size(in_file));

			while(!!ifstr)
			{
				int ch = ifstr.get();
				if(ch == std::istream::traits_type::eof())
					break;

				data.emplace_back(t_word(8, ch));
			}

			std::cerr << "Read " << data.size() << " bytes of raw data." << std::endl;
		}

		// output file
		std::ostream *postr = &std::cout;
		std::ofstream ofstr(out_rom);

		if(out_rom != "")
		{
			if(!ofstr)
			{
				std::cerr << "Cannot open output file \""
					<< out_rom << "\"." << std::endl;
				return -1;
			}

			postr = &ofstr;
		}

		// set rom generator function
		std::string (*gen_rom_fkt)(const t_words&, int, int, bool, bool, bool)
			= &gen_rom_vhdl;
		if(rom_type == "vhdl")
			gen_rom_fkt = &gen_rom_vhdl;
		else if(rom_type == "sv")
			gen_rom_fkt = &gen_rom_sv;
		else if(rom_type == "hex")
			gen_rom_fkt = &gen_rom_hex;

		// generate rom
		(*postr) << (*gen_rom_fkt)(data, line_len, num_ports,
			direct_ports, fill_rom, print_chars) << std::endl;
	}
	catch(const std::exception& ex)
	{
		std::cerr << "Error: " << ex.what() << std::endl;
		return -1;
	}

	return 0;
}
