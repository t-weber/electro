/**
 * create a font rom
 * @author Tobias Weber
 * @date jan-2022, apr-2024
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://freetype.org/freetype2/docs/reference/index.html
 *   - https://freetype.org/freetype2/docs/tutorial/step2.html
 *
 * Examples:
 *   - ./genfont --font DejaVuSansMono.ttf --type c --output ../../../micro_proc/lib/characters.c
 *   - ./genfont -h 24 -w 24 --target_height 24 --target_pitch 2 -f DejaVuSansMono.ttf -t vhdl -o font.vhdl
 */

#include "genfont.h"

#include <iostream>

#include <boost/algorithm/string.hpp>
#include <boost/program_options.hpp>
namespace args = boost::program_options;



int main(int argc, char **argv)
{
	Config cfg{};
	bool show_help = false;
	std::string rom_type = "c";

	bool reverse_lines = false;
	bool reverse_cols = false;
	bool transpose = false;

	// parse arguments
	args::options_description arg_descr("Font generator arguments");
	arg_descr.add_options()
		("help", args::bool_switch(&show_help), "show help")
		("font,f", args::value<decltype(cfg.font_file)>(&cfg.font_file),
			("font file, default: " + cfg.font_file).c_str())
		("output,o", args::value<decltype(cfg.out_rom)>(&cfg.out_rom),
			"output font rom file")
		("module,m", args::value<decltype(cfg.entity_name)>(&cfg.entity_name),
			("module name, default: " + cfg.entity_name).c_str())
		("type,t", args::value<decltype(rom_type)>(&rom_type),
			("output type (c/vhdl/sv/v/v-opt), default: " + rom_type).c_str())
		("sync,s", args::value<decltype(cfg.sync)>(&cfg.sync),
			("produce synchronous design, default: " + std::to_string(cfg.sync)).c_str())
		("first_char,c", args::value<decltype(cfg.ch_first)>(&cfg.ch_first),
			("first char, default: " + std::to_string(cfg.ch_first)).c_str())
		("last_char,l", args::value<decltype(cfg.ch_last)>(&cfg.ch_last),
			("last char, default: " + std::to_string(cfg.ch_last)).c_str())
		("font_width,w", args::value<decltype(cfg.font_width)>(&cfg.font_width),
			("font width, default: " + std::to_string(cfg.font_width)).c_str())
		("font_height,h", args::value<decltype(cfg.font_height)>(&cfg.font_height),
			("font height, default: " + std::to_string(cfg.font_height)).c_str())
		("target_height", args::value<decltype(cfg.target_height)>(&cfg.target_height),
			("target height, default: " + std::to_string(cfg.target_height)).c_str())
		("target_top", args::value<decltype(cfg.target_top)>(&cfg.target_top),
			("target top, default: " + std::to_string(cfg.target_top)).c_str())
		("target_left", args::value<decltype(cfg.target_left)>(&cfg.target_left),
			("target left, default: " + std::to_string(cfg.target_left)).c_str())
		("target_pitch", args::value<decltype(cfg.target_pitch)>(&cfg.target_pitch),
			("target pitch, default: " + std::to_string(cfg.target_pitch)).c_str())
		("pitch_bits", args::value<decltype(cfg.pitch_bits)>(&cfg.pitch_bits),
			("bits per pitch, default: " + std::to_string(cfg.pitch_bits)).c_str())
		("local_params", args::value<decltype(cfg.local_params)>(&cfg.local_params),
			("use local parameters, default: " + std::to_string(cfg.local_params)).c_str())
		("check_bounds", args::value<decltype(cfg.check_bounds)>(&cfg.check_bounds),
			("check index bounds, default: " + std::to_string(cfg.check_bounds)).c_str())
		("reverse_lines", args::bool_switch(&reverse_lines), "reverse line order")
		("reverse_cols", args::bool_switch(&reverse_cols), "reverse column order")
		("transpose", args::bool_switch(&transpose), "transpose bits");

	auto argparser = args::command_line_parser{argc, argv};
	argparser.style(args::command_line_style::default_style);
	argparser.options(arg_descr);

	auto parsedArgs = argparser.run();
	args::variables_map mapArgs;
	args::store(parsedArgs, mapArgs);
	args::notify(mapArgs);

	if(show_help)
	{
		std::cout << arg_descr << std::endl;
		return 0;
	}


	// load the font
	::FT_Library freetype{};
	if(::FT_Init_FreeType(&freetype))
	{
		std::cerr << "Error: Cannot initialise Freetype."
			<< std::endl;
		return -1;
	}

	::FT_Face face{};
	if(FT_New_Face(freetype, cfg.font_file.c_str(), 0, &face))
	{
		std::cerr << "Error: Cannot load font \""
			<< cfg.font_file << "\"."
			<< std::endl;
		return -1;
	}

	if(::FT_Set_Pixel_Sizes(face, cfg.font_width, cfg.font_height))
	{
		std::cerr << "Error: Cannot set font size."
			<< std::endl;
		return -1;
	}


	// create the font bitmaps
	FontBits fontbits = create_font(face, cfg);
	trafo_font(cfg, fontbits, reverse_lines, reverse_cols, transpose);


	bool ok = false;
	if(boost::to_lower_copy(rom_type) == "c")
	{
		ok = create_font_c(fontbits, cfg);
	}
	else if(boost::to_lower_copy(rom_type) == "vhdl")
	{
		ok = create_font_vhdl(fontbits, cfg);
	}
	/*else if(boost::to_lower_copy(rom_type) == "vhdl-opt")
	{
		ok = optimise_font(cfg, fontbits);
		if(ok)
			ok = create_font_vhdl_opt(fontbits, cfg);
	}*/
	else if(boost::to_lower_copy(rom_type) == "sv")
	{
		ok = create_font_sv(fontbits, cfg);
	}
	else if(boost::to_lower_copy(rom_type) == "v")
	{
		ok = create_font_v(fontbits, cfg);
	}
	else if(boost::to_lower_copy(rom_type) == "v-opt")
	{
		ok = optimise_font(cfg, fontbits);
		if(ok)
			ok = create_font_v_opt(fontbits, cfg);
	}

	if(ok)
	{
		unsigned int num_chars = cfg.ch_last - cfg.ch_first;
		unsigned int char_size = cfg.target_height * cfg.target_pitch * cfg.pitch_bits / 8;

		std::cerr.precision(2);
		std::cerr << "Info: Created font ROM: "
			<< "\"" << cfg.font_file << "\" -> \"" << cfg.out_rom << "\".\n"
			<< "Info: Number of characters: " << num_chars << ","
			<< " character size: " << char_size << " B,"
			<< " ROM size: " << num_chars * char_size / 1024. << " kiB."
			<< std::endl;
	}
	else
	{
		std::cerr << "Error: Font ROM creation failed."
			<< std::endl;
	}


	// clean up
	::FT_Done_Face(face);
	::FT_Done_FreeType(freetype);

	return ok ? 0 : -1;;
}
