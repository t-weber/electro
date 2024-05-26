/**
 * create a font for use with the oled module
 * @author Tobias Weber
 * @date jan-2022, apr-2024
 * @license see 'LICENSE' file
 */

#include "genfont.h"

#include <iostream>
#include <fstream>
#include <iomanip>



/**
 * output a c file
 */
bool create_font_c(const FontBits& fontbits, const Config& cfg)
{
	std::ofstream *ofstr = nullptr;
	std::ostream *ostr = &std::cout;
	if(cfg.out_rom != "")
	{
		ofstr = new std::ofstream(cfg.out_rom);
		ostr = ofstr;
	}


	(*ostr) << "#include <stdint.h>\n\n";

	(*ostr) << "const uint16_t g_characters_first  = " << cfg.ch_first << ";\n";
	(*ostr) << "const uint16_t g_characters_last   = " << cfg.ch_last << ";\n";
	(*ostr) << "const uint16_t g_characters_pitch  = " << cfg.target_pitch << ";\n";
	(*ostr) << "const uint16_t g_characters_width  = " << cfg.target_pitch * cfg.pitch_bits << ";\n";
	(*ostr) << "const uint16_t g_characters_height = " << cfg.target_height << ";\n\n";

	// see: https://www.arduino.cc/reference/en/language/variables/utilities/progmem/
	(*ostr) << "#ifndef PROGMEM\n"
		<< "\t#define PROGMEM\n"
		<< "#endif\n"
		<< "const uint8_t g_characters[" << (cfg.ch_last - cfg.ch_first) << "]"
		<< "[" << cfg.target_height*cfg.target_pitch << "] PROGMEM =\n{\n";


	for(const CharBits& charbits : fontbits.charbits)
	{

		(*ostr) << "\n\t/* char #" << charbits.ch_num
			<< std::hex << " (0x" << std::hex << charbits.ch_num << ")" << std::dec
			<< ": '" << static_cast<char>(charbits.ch_num) << "'"
			<< ", height: " << charbits.height
			<< ", width: " << charbits.width
			<< ", pitch: " << charbits.pitch
			<< ", bearing x: " << charbits.bearing_x
			<< ", bearing y: " << charbits.bearing_y
			<< ", left: " << charbits.left
			<< ", top: " << charbits.top
			<< " */\n";

		(*ostr) << "\t{\n";

		for(const std::vector<boost::dynamic_bitset<>>& linebits : charbits.lines)
		{
			for(std::size_t x = 0; x < linebits.size(); ++x)
			{
				if(x == 0)
					(*ostr) << "\t\t";
				(*ostr) << "0b" << linebits[x] << ",";
			}

			(*ostr) << "\n";
		}

		(*ostr) << "\t}," << std::endl;
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
