/**
 * create a font for use with the oled module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://freetype.org/freetype2/docs/reference/index.html
 *   - https://freetype.org/freetype2/docs/tutorial/step2.html
 *
 * g++ -Wall -Wextra -Weffc++ -I/usr/include/freetype2 -o create_font create_font.cpp -lfreetype
 * ./create_font > ../lib/characters.c
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
	const unsigned int target_top = 12;
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
	std::cout << "const uint16_t g_characters_first = " << ch_first << ";\n";
	std::cout << "const uint16_t g_characters_last = " << ch_last << ";\n";
	std::cout << "const uint16_t g_characters_pitch = " << target_pitch << ";\n";
	std::cout << "const uint16_t g_characters_width = " << target_pitch*8 << ";\n";
	std::cout << "const uint16_t g_characters_height = " << target_height << ";\n\n";

	// see: https://www.arduino.cc/reference/en/language/variables/utilities/progmem/
	std::cout << "const uint8_t g_characters[" << (ch_last - ch_first) << "]"
		<< "[" << target_height*target_pitch << "] PROGMEM = \n{\n";

	for(::FT_ULong ch = ch_first; ch < ch_last; ++ch)
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

		auto output_bits = [pitch, target_pitch, bitmap](
			unsigned int y, unsigned int shift_x, bool force_zero)
		{
			for(int x=0; x<std::min(pitch, target_pitch); ++x)
			{
				unsigned char byte = force_zero ? 0 : bitmap[y*pitch + x];

				if(x == 0)
					std::cout << "\t\t";

				std::bitset<8> bits(byte >> shift_x);
				std::cout << "0b" << bits << ", ";
			}
			std::cout << "\n";
		};

		std::cout << "\n\t/* char number " << ch
			<< ": \"" << static_cast<char>(ch) << "\""
			<< ", height: " << height
			<< ", width: " << width
			<< ", pitch: " << pitch
			<< ", bearing x: " << (metrics->horiBearingX >> 6)
			<< ", bearing y: " << (metrics->horiBearingY >> 6)
			<< ", left: " << glyph->bitmap_left
			<< ", top: " << glyph->bitmap_top
			<< " */"<< std::endl;

		std::cout << "\t{\n";

		FT_Int shift_x = glyph->bitmap_left;
		FT_Int shift_y = target_top - glyph->bitmap_top;

		// top filler
		unsigned int top_filler_size = (target_height-(height + shift_y))/2 + shift_y;
		if(height + shift_y < target_height)
		{
			for(unsigned int y=0; y<=top_filler_size; ++y)
				output_bits(y, 0, true);
		}

		// char
		for(unsigned int y=0; y<std::min(height, target_height); ++y)
			output_bits(y, shift_x, false);

		// bottom filler
		for(unsigned int y=height + top_filler_size + 1; y<target_height; ++y)
			output_bits(y, 0, true);

		std::cout << "\t},\n";
	}

	std::cout << "};";
	std::cout << std::endl;


	// clean up
	::FT_Done_Face(face);
	::FT_Done_FreeType(freetype);

	return 0;
}
