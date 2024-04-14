/**
 * create a font for use with the oled module
 * @author Tobias Weber
 * @date jan-2022, apr-2024
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://freetype.org/freetype2/docs/reference/index.html
 *   - https://freetype.org/freetype2/docs/tutorial/step2.html
 *
 * ./genfont --font DejaVuSansMono.ttf --type c --output ../../../micro_proc/lib/characters.c
 */

#include <iostream>
#include <fstream>
#include <iomanip>

#include <ft2build.h>
#include <freetype/freetype.h>

#include <boost/dynamic_bitset.hpp>
#include <boost/algorithm/string.hpp>
#include <boost/program_options.hpp>
namespace args = boost::program_options;



/**
 * settings
 */
struct Config
{
	std::string font_file = "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf";
	std::string out_rom;
	std::string entity_name = "font";

	FT_UInt font_width = 15;
	FT_UInt font_height = 16;

	unsigned int target_height = 16;
	unsigned int target_top = 12;

	unsigned int pitch_bits = 8;
	int target_pitch = 1;

	::FT_ULong ch_first = 0x20;
	::FT_ULong ch_last = 0x7f;
};



/**
 * output a c file
 */
bool create_font_c(::FT_Face& face, const Config& cfg)
{
	std::ofstream *ofstr = nullptr;
	std::ostream *ostr = &std::cout;
	if(cfg.out_rom != "")
	{
		ofstr = new std::ofstream(cfg.out_rom);
		ostr = ofstr;
	}


	(*ostr) << "#include <stdint.h>\n\n";

	(*ostr) << "const uint16_t g_characters_first = " << cfg.ch_first << ";\n";
	(*ostr) << "const uint16_t g_characters_last = " << cfg.ch_last << ";\n";
	(*ostr) << "const uint16_t g_characters_pitch = " << cfg.target_pitch << ";\n";
	(*ostr) << "const uint16_t g_characters_width = " << cfg.target_pitch * cfg.pitch_bits << ";\n";
	(*ostr) << "const uint16_t g_characters_height = " << cfg.target_height << ";\n\n";

	// see: https://www.arduino.cc/reference/en/language/variables/utilities/progmem/
	(*ostr) << "const uint8_t g_characters[" << (cfg.ch_last - cfg.ch_first) << "]"
		<< "[" << cfg.target_height*cfg.target_pitch << "] PROGMEM =\n{\n";

	for(::FT_ULong ch = cfg.ch_first; ch < cfg.ch_last; ++ch)
	{
		if(::FT_Load_Char(face, ch, FT_LOAD_TARGET_MONO | FT_LOAD_NO_HINTING | FT_LOAD_RENDER))
		{
			std::cerr << "Error: Cannot load char 0x" << std::hex << ch << "." << std::endl;
			continue;
		}

		const auto *glyph = face->glyph;
		const auto *metrics = &glyph->metrics;
		const unsigned int height = glyph->bitmap.rows;
		const unsigned int width = glyph->bitmap.width;
		const int pitch = glyph->bitmap.pitch;
		const unsigned char *bitmap = glyph->bitmap.buffer;

		auto output_bits = [pitch, bitmap, ostr, &cfg](
			unsigned int y, unsigned int shift_x, bool force_zero)
		{
			for(int x = 0; x < std::min(pitch, cfg.target_pitch); ++x)
			{
				unsigned char byte = force_zero ? 0 : bitmap[y*pitch + x];
				if(x == 0)
					byte >>= shift_x;

				if(x == 0)
					(*ostr) << "\t\t";

				(*ostr) << "0b" << boost::dynamic_bitset{cfg.pitch_bits, byte} << ",";
			}

			(*ostr) << "\n";
		};

		(*ostr) << "\n\t/* char number " << ch
			<< ": '" << static_cast<char>(ch) << "'"
			<< ", height: " << height
			<< ", width: " << width
			<< ", pitch: " << pitch
			<< ", bearing x: " << (metrics->horiBearingX >> 6)
			<< ", bearing y: " << (metrics->horiBearingY >> 6)
			<< ", left: " << glyph->bitmap_left
			<< ", top: " << glyph->bitmap_top
			<< " */\n";

		(*ostr) << "\t{\n";

		FT_Int shift_x = glyph->bitmap_left;
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

		(*ostr) << "\t},\n";
	}

	(*ostr) << "};" << std::endl;


	// clean up
	if(ofstr)
	{
		delete ofstr;
		ofstr = nullptr;
	}

	return true;
}



/**
 * output a vhdl file
 */
bool create_font_vhdl(::FT_Face& face, const Config& cfg)
{
	std::ofstream *ofstr = nullptr;
	std::ostream *ostr = &std::cout;
	if(cfg.out_rom != "")
	{
		ofstr = new std::ofstream(cfg.out_rom);
		ostr = ofstr;
	}


	(*ostr) << "library ieee;\n"
		<< "use ieee.std_logic_1164.all;\n"
		<< "use work.conv.all;\n\n";

	(*ostr) << "\nentity " << cfg.entity_name << " is\n"
		<< "\tgeneric(\n"
		<< "\t\tconstant FIRST_CHAR : natural := " << cfg.ch_first << ";\n"
		<< "\t\tconstant LAST_CHAR : natural := " << cfg.ch_last << ";\n"
		<< "\t\tconstant CHAR_PITCH : natural := " << cfg.target_pitch << ";\n"
		<< "\t\tconstant CHAR_WIDTH : natural := " << cfg.target_pitch * cfg.pitch_bits << ";\n"
		<< "\t\tconstant CHAR_HEIGHT : natural := " << cfg.target_height << "\n"
		<< "\t);\n\n"
		<< "\tport(\n"
		<< "\t\tin_char : in std_logic_vector(" << std::ceil(std::log2(cfg.ch_last)) << " downto 0);\n"
		<< "\t\tin_x : in std_logic_vector(" << std::ceil(std::log2(cfg.target_pitch * cfg.pitch_bits)) << " downto 0);\n"
		<< "\t\tin_y : in std_logic_vector(" << std::ceil(std::log2(cfg.target_height)) << " downto 0);\n"
		<< "\t\tout_pixel : out std_logic\n"
		<< "\t);\n\n"
		<< "end entity;\n\n";

	(*ostr) << "\narchitecture " << cfg.entity_name << "_impl of " << cfg.entity_name << " is\n";

	(*ostr) << "\tsubtype t_line is std_logic_vector(CHAR_WIDTH-1 downto 0);\n"
		<< "\ttype t_char is array(0 to CHAR_HEIGHT-1) of t_line;\n"
		<< "\ttype t_chars is array(FIRST_CHAR to LAST_CHAR-1) of t_char;\n";

	(*ostr) << "\n\tconstant chars : t_chars :=\n\t(";

	for(::FT_ULong ch = cfg.ch_first; ch < cfg.ch_last; ++ch)
	{
		if(::FT_Load_Char(face, ch, FT_LOAD_TARGET_MONO | FT_LOAD_NO_HINTING | FT_LOAD_RENDER))
		{
			std::cerr << "Error: Cannot load char 0x" << std::hex << ch << "." << std::endl;
			continue;
		}

		const auto *glyph = face->glyph;
		const auto *metrics = &glyph->metrics;
		const unsigned int height = glyph->bitmap.rows;
		const unsigned int width = glyph->bitmap.width;
		const int pitch = glyph->bitmap.pitch;
		const unsigned char *bitmap = glyph->bitmap.buffer;

		auto output_bits = [pitch, bitmap, ostr, &cfg](
			unsigned int y, unsigned int shift_x, bool force_zero)
		{
			int max_x = std::min(pitch, cfg.target_pitch);

			(*ostr) << "\t\t\t\"";

			for(int x = 0; x < max_x; ++x)
			{
				unsigned char byte = force_zero ? 0 : bitmap[y*pitch + x];
				if(x == 0)
					byte >>= shift_x;

				(*ostr) << boost::dynamic_bitset{cfg.pitch_bits, byte};
			}

			(*ostr) << "\"";
		};

		(*ostr) << "\n\t\t-- char number " << ch
			<< ": '" << static_cast<char>(ch) << "'"
			<< ", height: " << height
			<< ", width: " << width
			<< ", pitch: " << pitch
			<< ", bearing x: " << (metrics->horiBearingX >> 6)
			<< ", bearing y: " << (metrics->horiBearingY >> 6)
			<< ", left: " << glyph->bitmap_left
			<< ", top: " << glyph->bitmap_top
			<< "\n";

		(*ostr) << "\t\t(\n";

		FT_Int shift_x = glyph->bitmap_left;
		FT_Int shift_y = cfg.target_top;
		if(glyph->bitmap_top > 0)
			shift_y -= glyph->bitmap_top;

		// top filler
		int top_filler_size = (cfg.target_height-(height + shift_y))/2 + shift_y;
		if(top_filler_size < 0)
			top_filler_size = 0;

		unsigned int cur_y_top = 0;
		if(height + shift_y < cfg.target_height)
		{
			for(int y = 0; y <= top_filler_size; ++y)
			{
				output_bits(y, 0, true);
				++cur_y_top;

				if((unsigned int)y < cfg.target_height - 1)
					(*ostr) << ",";
				(*ostr) << " -- top filler line " << y + 1;
				(*ostr) << "\n";
			}
		}

		// char
		unsigned int cur_y = cur_y_top;
		for(unsigned int y = 0; y < std::min(height, cfg.target_height - cur_y_top); ++y)
		{
			output_bits(y, shift_x, false);
			++cur_y;

			if(y + cur_y_top < cfg.target_height - 1)
				(*ostr) << ",";
			(*ostr) << " -- char line " << y + 1;
			(*ostr) << "\n";
		}

		// bottom filler
		for(unsigned int y = cur_y; y < cfg.target_height; ++y)
		{
			output_bits(y, 0, true);

			if(y < cfg.target_height - 1)
				(*ostr) << ",";
			(*ostr) << " -- bottom filler line " << y - cur_y + 1;
			(*ostr) << "\n";
		}

		(*ostr) << "\t\t)";
		if(ch < cfg.ch_last - 1)
			(*ostr) << ",";
		(*ostr) << "\n";
	}

	(*ostr) << "\n\t);\n";

	(*ostr) << "\nbegin\n";

	(*ostr) << "\n\tout_pixel <= chars(to_int(in_char))(to_int(in_y))(to_int(in_x));\n";

	(*ostr) << "\nend architecture;" << std::endl;

	return true;
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
			("output type (c/vhdl), default: " + rom_type).c_str())
		("first_char,f", args::value<decltype(cfg.ch_first)>(&cfg.ch_first),
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


	bool ok = false;
	if(boost::to_lower_copy(rom_type) == "c")
		ok = create_font_c(face, cfg);
	else if(boost::to_lower_copy(rom_type) == "vhdl")
		ok = create_font_vhdl(face, cfg);

	if(!ok)
		std::cerr << "Font creation failed." << std::endl;


	// clean up
	::FT_Done_Face(face);
	::FT_Done_FreeType(freetype);

	return ok ? 0 : -1;;
}
