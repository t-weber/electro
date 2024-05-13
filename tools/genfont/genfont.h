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

#include <boost/dynamic_bitset.hpp>



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
	unsigned int target_top = 12;
	unsigned int target_left = 0;

	unsigned int pitch_bits = 8;
	int target_pitch = 1;

	unsigned int ch_first = 0x20;
	unsigned int ch_last = 0x7f;

	bool local_params = true;
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

	std::vector<std::vector<boost::dynamic_bitset<>>> lines;
};


struct FontBits
{
	std::vector<CharBits> charbits;
};



/**
 * output a c file
 */
extern bool create_font_c(const FontBits& fontbits, const Config& cfg);


/**
 * output a vhdl file
 */
extern bool create_font_vhdl(const FontBits& fontbits, const Config& cfg);


/**
 * output an sv file
 */
extern bool create_font_sv(const FontBits& fontbits, const Config& cfg);


/**
 * output an v file
 */
extern bool create_font_v(const FontBits& fontbits, const Config& cfg);


#endif
