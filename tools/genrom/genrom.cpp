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
#include "v.h"
#include "hex.h"
#include "img.h"


int main(int argc, char** argv)
{
	try
	{
		Config cfg;
		cfg.max_line_len = 16;
		cfg.num_ports = 2;
		cfg.direct_ports = false;
		cfg.fill_rom = true;
		cfg.print_chars = true;
		cfg.check_bounds = true;
		cfg.module_name = "rom";

		std::string rom_type = "vhdl";
		std::string in_filename, out_rom;

		std::string repeat_data;
		std::size_t repeat_times = 0;

		args::options_description arg_descr("ROM generator arguments");
		arg_descr.add_options()
			("linelen,l", args::value<decltype(cfg.max_line_len)>(&cfg.max_line_len),
				("line length, default: "
					+ std::to_string(cfg.max_line_len)).c_str())
			("fill,f", args::value<bool>(&cfg.fill_rom),
				("fill non-used rom fields with zeros, default: "
					+ std::to_string(cfg.fill_rom)).c_str())
			("chars,c", args::value<bool>(&cfg.print_chars),
				("print characters, default: "
					+ std::to_string(cfg.print_chars)).c_str())
			("type,t", args::value<decltype(rom_type)>(&rom_type),
				("output rom type (vhdl/sv/v/hex), default: "
					+ rom_type).c_str())
			("ports,p", args::value<decltype(cfg.num_ports)>(&cfg.num_ports),
				("number of memory ports, default: "
					+ std::to_string(cfg.num_ports)).c_str())
			("direct_ports,d", args::value<bool>(&cfg.direct_ports),
				("generate direct ports, default: "
					+ std::to_string(cfg.direct_ports)).c_str())
			("check_bounds,b", args::value<decltype(cfg.check_bounds)>(&cfg.check_bounds),
				("check index bounds, default: " + std::to_string(cfg.check_bounds)).c_str())
			("module,m", args::value<decltype(cfg.module_name)>(&cfg.module_name),
				("module name, default: "
					+ cfg.module_name).c_str())
			("repeat_data,r", args::value<decltype(repeat_data)>(&repeat_data),
				"data word to repeat (instead of input file)")
			("repeat_times,n", args::value<decltype(repeat_times)>(&repeat_times),
				("number of times to repeat data word, default: "
					+ std::to_string(repeat_times)).c_str())
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


		if(in_filename != "")
		{
			// get data from input file
			std::filesystem::path in_file(in_filename);
			if(!std::filesystem::exists(in_file))
			{
				std::cerr << "Error: Input file \"" << in_filename
					<< "\" does not exist." << std::endl;
				return -1;
			}

			std::ifstream ifstr(in_file);
			if(!ifstr)
			{
				std::cerr << "Error: Cannot open input file \""
					<< in_filename << "\"." << std::endl;
				return -1;
			}

			// read input file
			std::string ext = boost::to_lower_copy(in_file.extension().string());

			if(ext == ".png")
			{
				std::size_t w, h, ch;
				std::tie(w, h, ch, cfg.data) = read_png(in_file);
				std::cerr << "Info: Read PNG image with size "
					<< w << " x " << h << " x " << ch << "."
					<< std::endl;

				cfg.print_chars = false;
			}
			else if(ext == ".jpg" || ext == ".jpeg")
			{
				std::size_t w, h, ch;
				std::tie(w, h, ch, cfg.data) = read_jpg(in_file);
				std::cerr << "Info: Read JPG image with size "
					<< w << " x " << h << " x " << ch << "."
					<< std::endl;

				cfg.print_chars = false;
			}
			else  // read raw file
			{
				cfg.data.reserve(std::filesystem::file_size(in_file));

				while(!!ifstr)
				{
					int ch = ifstr.get();
					if(ch == std::istream::traits_type::eof())
						break;

					cfg.data.emplace_back(t_word(8, ch));
				}

				std::cerr << "Info: Read " << cfg.data.size()
					<< " bytes of raw data."
					<< std::endl;
			}
		}
		else if(repeat_data != "")
		{
			// get data from given pattern
			t_word word(repeat_data);

			cfg.data.reserve(repeat_times);
			for(std::size_t idx = 0; idx < repeat_times; ++idx)
				cfg.data.emplace_back(word);
		}
		else
		{
			// no input data given
			std::cerr << arg_descr << std::endl;
			return -1;
		}


		// output file
		std::ostream *postr = &std::cout;
		std::ofstream ofstr(out_rom);

		if(out_rom != "")
		{
			if(!ofstr)
			{
				std::cerr << "Error: Cannot open output file \""
					<< out_rom << "\"." << std::endl;
				return -1;
			}

			postr = &ofstr;
		}

		// set rom generator function
		std::string (*gen_rom_fkt)(const Config&) = &gen_rom_vhdl;

		if(boost::to_lower_copy(rom_type) == "vhdl")
			gen_rom_fkt = &gen_rom_vhdl;
		else if(boost::to_lower_copy(rom_type) == "sv")
			gen_rom_fkt = &gen_rom_sv;
		else if(boost::to_lower_copy(rom_type) == "v")
			gen_rom_fkt = &gen_rom_v;
		else if(boost::to_lower_copy(rom_type) == "hex")
			gen_rom_fkt = &gen_rom_hex;

		// generate rom
		(*postr) << (*gen_rom_fkt)(cfg) << std::endl;
	}
	catch(const std::exception& ex)
	{
		std::cerr << "Error: " << ex.what() << std::endl;
		return -1;
	}

	return 0;
}
