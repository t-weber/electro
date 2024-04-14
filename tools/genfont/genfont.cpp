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

#include <ft2build.h>
#include <freetype/freetype.h>

#include <boost/algorithm/string.hpp>
#include <boost/program_options.hpp>
namespace args = boost::program_options;



/**
 * create a bitmap of the font
 */
FontBits create_font(::FT_Face& face, const Config& cfg)
{
	FontBits fontbits{};

	for(::FT_ULong ch = cfg.ch_first; ch < cfg.ch_last; ++ch)
	{
		if(::FT_Load_Char(face, ch, FT_LOAD_TARGET_MONO | FT_LOAD_NO_HINTING | FT_LOAD_RENDER))
		{
			std::cerr << "Error: Cannot load char 0x" << std::hex << ch << "." << std::endl;
			continue;
		}

		CharBits charbits{};
		charbits.ch_num = ch;

		const auto *glyph = face->glyph;
		const auto *metrics = &glyph->metrics;
		const unsigned int height = glyph->bitmap.rows;
		const unsigned int width = glyph->bitmap.width;
		const int pitch = glyph->bitmap.pitch;
		const unsigned char *bitmap = glyph->bitmap.buffer;

		charbits.height = height;
		charbits.width = width;
		charbits.pitch = pitch;
		charbits.bearing_x = (metrics->horiBearingX >> 6);
		charbits.bearing_y = (metrics->horiBearingY >> 6);
		charbits.left = glyph->bitmap_left;
		charbits.top = glyph->bitmap_top;


		auto output_bits = [pitch, bitmap, &cfg, &charbits](
			unsigned int y, unsigned int shift_x, bool force_zero)
		{
			std::vector<boost::dynamic_bitset<>> linebits;

			for(int x = 0; x < std::min(pitch, cfg.target_pitch); ++x)
			{
				unsigned char byte = force_zero ? 0 : bitmap[y*pitch + x];
				byte >>= shift_x;

				if(x > 0)
				{
					unsigned char prev_byte =
						force_zero ? 0 : bitmap[y*pitch + x - 1];

					// move shifted out bits from previous byte to current byte
					prev_byte <<= cfg.pitch_bits - shift_x;
					byte |= prev_byte;
				}

				linebits.emplace_back(boost::dynamic_bitset{cfg.pitch_bits, byte});
			}

			charbits.lines.emplace_back(std::move(linebits));
		};


		FT_Int shift_x = cfg.target_left + glyph->bitmap_left;
		FT_Int shift_y = cfg.target_top;
		if(glyph->bitmap_top > 0)
			shift_y -= glyph->bitmap_top;

		// top filler
		unsigned int cur_y_top = 0;
		int top_filler_size = (cfg.target_height-(height + shift_y))/2 + shift_y;
		if(top_filler_size < 0)
			top_filler_size = 0;

		if(height + shift_y < cfg.target_height)
		{
			for(int y = 0; y <= top_filler_size; ++y)
			{
				output_bits(y, 0, true);
				++cur_y_top;
			}
		}

		// char
		unsigned int cur_y = cur_y_top;
		for(unsigned int y = 0; y < std::min(height, cfg.target_height - cur_y_top); ++y)
		{
			output_bits(y, shift_x, false);
			++cur_y;
		}

		// bottom filler
		for(unsigned int y = cur_y; y < cfg.target_height; ++y)
			output_bits(y, 0, true);


		fontbits.charbits.emplace_back(std::move(charbits));
	}

	return fontbits;
}



int main(int argc, char **argv)
{
	Config cfg{};
	bool show_help = false;
	std::string rom_type = "c";

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
			("output type (c/vhdl/sv), default: " + rom_type).c_str())
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
			("bits per pitch, default: " + std::to_string(cfg.pitch_bits)).c_str());

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
		std::cerr << "Error: Cannot initialise Freetype." << std::endl;
		return -1;
	}

	::FT_Face face{};
	if(FT_New_Face(freetype, cfg.font_file.c_str(), 0, &face))
	{
		std::cerr << "Error: Cannot load font \"" << cfg.font_file << "\"." << std::endl;
		return -1;
	}

	if(::FT_Set_Pixel_Sizes(face, cfg.font_width, cfg.font_height))
	{
		std::cerr << "Error: Cannot set font size." << std::endl;
		return -1;
	}


	// create the font bitmaps
	FontBits fontbits = create_font(face, cfg);


	bool ok = false;
	if(boost::to_lower_copy(rom_type) == "c")
		ok = create_font_c(fontbits, cfg);
	else if(boost::to_lower_copy(rom_type) == "vhdl")
		ok = create_font_vhdl(fontbits, cfg);
	else if(boost::to_lower_copy(rom_type) == "sv")
		ok = create_font_sv(fontbits, cfg);

	if(ok)
	{
		unsigned int num_chars = cfg.ch_last - cfg.ch_first;
		unsigned int char_size = cfg.target_height * cfg.target_pitch * cfg.pitch_bits / 8;

		std::cerr << "Created font ROM: "
			<< "\"" << cfg.font_file << "\" -> \"" << cfg.out_rom << "\".\n"
			<< "Number of characters: " << num_chars << ","
			<< " character size: " << char_size << " B,"
			<< " ROM size: " << num_chars * char_size / 1024 << " kiB."
			<< std::endl;
	}
	else
	{
		std::cerr << "Font ROM creation failed."
			<< std::endl;
	}


	// clean up
	::FT_Done_Face(face);
	::FT_Done_FreeType(freetype);

	return ok ? 0 : -1;;
}
