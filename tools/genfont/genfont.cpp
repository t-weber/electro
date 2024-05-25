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
#include <algorithm>



template<class t_bitset>
static void reverse_bitset(t_bitset& bitset)
{
	std::size_t N = bitset.size();
	t_bitset bitset_cpy = bitset;

	for(std::size_t i = 0; i < N; ++i)
		bitset[N - i - 1] = bitset_cpy[i];
}



/**
 * create a bitmap of the font
 */
FontBits create_font(::FT_Face& face, const Config& cfg)
{
	FontBits fontbits{};

	for(::FT_ULong ch = cfg.ch_first; ch < cfg.ch_last; ++ch)
	{
		if(::FT_Load_Char(face, ch,
			FT_LOAD_TARGET_MONO | FT_LOAD_NO_HINTING | FT_LOAD_RENDER))
		{
			std::cerr << "Error: Cannot load char 0x"
				<< std::hex << ch << "."
				<< std::endl;
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
		int top_filler_size = (cfg.target_height - (height + shift_y))/2 + shift_y;
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



static bool get_char_pixel(CharBits& charbits, std::size_t line, std::size_t col)
{
	const std::size_t pitch_bits = charbits.lines[0][0].size();

	return charbits.lines[line][col / pitch_bits][col % pitch_bits];
}



static void trafo_char(Config& cfg, CharBits& charbits,
	bool reverse_lines, bool reverse_columns, bool transpose)
{
	if(reverse_lines)
	{
		std::reverse(charbits.lines.begin(), charbits.lines.end());
	}

	if(reverse_columns)
	{
		for(auto& line : charbits.lines)
		{
			std::reverse(line.begin(), line.end());
			for(auto& subline : line)
				reverse_bitset(subline);
		}
	}

	if(transpose)
	{
		// old dimensions
		const std::size_t num_rows = charbits.lines.size();
		const std::size_t num_cols = cfg.target_pitch * static_cast<int>(cfg.pitch_bits);

		// set new dimensions
		cfg.target_pitch = 1;
		cfg.pitch_bits = num_rows;

		// create transposed data container
		decltype(charbits.lines) lines_transp;
		lines_transp.reserve(num_cols);
		for(std::size_t line_idx = 0; line_idx < num_rows; ++line_idx)
		{
			std::remove_reference_t<decltype(charbits.lines[0])> line;
			line.resize(1);
			line[0].resize(num_rows);
			lines_transp.emplace_back(std::move(line));
		}

		// transpose bits
		for(std::size_t line_idx = 0; line_idx < num_rows; ++line_idx)
		for(std::size_t col_idx = 0; col_idx < num_cols; ++col_idx)
			lines_transp[col_idx][0][line_idx] = get_char_pixel(charbits, line_idx, col_idx);

		charbits.lines = std::move(lines_transp);
	}
}



void trafo_font(Config& cfg, FontBits& fontbits,
	bool reverse_lines, bool reverse_columns, bool transpose)
{
	for(CharBits& ch : fontbits.charbits)
		trafo_char(cfg, ch, reverse_lines, reverse_columns, transpose);
}
