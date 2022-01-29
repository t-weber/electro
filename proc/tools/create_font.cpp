/**
 * create a font for use with the oled module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://freetype.org/freetype2/docs/reference/index.html
 *
 * g++ -Wall -Wextra -Weffc++ -I/usr/include/freetype2 -o create_font create_font.cpp -lfreetype
 */

#include <iostream>
#include <iomanip>
#include <bitset>

#include <ft2build.h>
#include <freetype/freetype.h>


int main([[maybe_unused]] int argc, [[maybe_unused]] char **argv)
{
	// settings
	const char *font_file = "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf";

	const FT_UInt font_width = 15;
	const FT_UInt font_height = 16;

	const unsigned int target_height = 16;
	const int target_pitch = 1;

	const ::FT_ULong ch_first = 0x20;
	const ::FT_ULong ch_last = 0x7f;


	// load the font
	::FT_Library freetype{};
	if(::FT_Init_FreeType(&freetype))
	{
		std::cerr << "Error: Cannot initialise Freetype." << std::endl;
		return -1;
	}

	::FT_Face face{};
	if(FT_New_Face(freetype, font_file, 0, &face))
	{
		std::cerr << "Error: Cannot load font \"" << font_file << "\"." << std::endl;
		return -1;
	}

	if(::FT_Set_Pixel_Sizes(face, font_width, font_height))
	{
		std::cerr << "Error: Cannot set font size." << std::endl;
		return -1;
	}


	// create the font file
	std::cout << "unsigned int g_characters_first = " << ch_first << ";\n";
	std::cout << "unsigned int g_characters_last = " << ch_last << ";\n";
	std::cout << "char g_characters[][" << target_height*target_pitch << "] = \n{\n";

	for(::FT_ULong ch = ch_first; ch < ch_last; ++ch)
	{
		if(::FT_Load_Char(face, ch, FT_LOAD_TARGET_MONO | FT_LOAD_NO_HINTING | FT_LOAD_RENDER))
		{
			std::cerr << "Error: Cannot load char 0x" << std::hex << ch << "." << std::endl;
			continue;
		}

		const unsigned int height = face->glyph->bitmap.rows;
		const unsigned int width = face->glyph->bitmap.width;
		const int pitch = face->glyph->bitmap.pitch;
		const unsigned char *bitmap = face->glyph->bitmap.buffer;

		auto output_bits = [pitch, target_pitch, bitmap](unsigned int y, bool force_zero)
		{
			for(int x=0; x<std::min(pitch, target_pitch); ++x)
			{
				unsigned char byte = force_zero ? 0 : bitmap[y*pitch + x];

				if(x == 0)
					std::cout << "\t\t";

				std::bitset<8> bits(byte);
				std::cout << "0b" << bits << ", ";
			}
			std::cout << "\n";
		};

		std::cout << "\n\t/* char number " << ch
			<< ": \"" << static_cast<char>(ch) << "\""
			<< ", height: " << height
			<< ", width: " << width
			<< ", pitch: " << pitch
			<< " */"<< std::endl;

		std::cout << "\t{\n";

		// top filler
		for(unsigned int y=0; y<=(target_height-height)/2; ++y)
			output_bits(y, true);

		// char
		for(unsigned int y=0; y<std::min(height, target_height); ++y)
			output_bits(y, false);

		// bottom filler
		for(unsigned int y=height + (target_height-height)/2 + 1; y<target_height; ++y)
			output_bits(y, true);

		std::cout << "\t},\n";
	}

	std::cout << "};";
	std::cout << std::endl;


	// clean up
	::FT_Done_Face(face);
	::FT_Done_FreeType(freetype);

	return 0;
}
