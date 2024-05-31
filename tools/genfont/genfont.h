/**
 * create a font rom
 * @author Tobias Weber
 * @date jan-2022, apr-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENFONT_H__
#define __GENFONT_H__


#include <string>
#include <vector>
#include <map>

#include <boost/dynamic_bitset.hpp>

#include <ft2build.h>
#include <freetype/freetype.h>



/**
 * settings
 */
struct Config
{
	std::string font_file = "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf";
	std::string out_rom;
	std::string entity_name = "font";

	unsigned int font_width = 15;
	unsigned int font_height = 16;

	unsigned int target_height = 16;
	int target_top = 12;
	int target_left = 0;

	unsigned int pitch_bits = 8;
	int target_pitch = 1;

	unsigned int ch_first = 0x20;
	unsigned int ch_last = 0x7f;

	bool local_params = true;
	bool check_bounds = true;
	bool sync = false;
};


struct CharBits
{
	unsigned int ch_num = 0;

	unsigned int width = 0;
	unsigned int height = 0;
	unsigned int pitch = 0;
	unsigned int bearing_x = 0;
	unsigned int bearing_y = 0;
	int left = 0;
	int top = 0;

	using t_bits = boost::dynamic_bitset<>;
	using t_line = std::vector<t_bits>;
	using t_lines = std::vector<t_line>;
	t_lines lines;
};


struct FontBits
{
	std::vector<CharBits> charbits;

	using t_addrs = std::vector<std::size_t>;
	using t_linesmap = std::map<CharBits::t_bits, t_addrs>;
	t_linesmap lines_opt;
};


// create a bitmap of the font
extern FontBits create_font(::FT_Face& face, const Config& cfg);

// apply transformations to the font's pixel maps
extern void trafo_font(Config& cfg, FontBits& fontbits,
	bool reverse_lines, bool reverse_columns, bool transpose);

// optimise lines
extern bool optimise_font(const Config& cfg, FontBits& fontbits);


// output a c file
extern bool create_font_c(const FontBits& fontbits, const Config& cfg);

// output a vhdl file
extern bool create_font_vhdl(const FontBits& fontbits, const Config& cfg);
extern bool create_font_vhdl_opt(const FontBits& fontbits, const Config& cfg);

// output an sv file
extern bool create_font_sv(const FontBits& fontbits, const Config& cfg);

// output an v file
extern bool create_font_v(const FontBits& fontbits, const Config& cfg);
extern bool create_font_v_opt(const FontBits& fontbits, const Config& cfg);


#endif
