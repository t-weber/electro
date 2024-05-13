/**
 * create a font rom
 * @author Tobias Weber
 * @date jan-2022, apr-2024, 11-may-2024
 * @license see 'LICENSE' file
 */

#include "genfont.h"

#include <iostream>
#include <fstream>
#include <iomanip>



/**
 * output a v file
 */
bool create_font_v(const FontBits& fontbits, const Config& cfg)
{
	std::ofstream *ofstr = nullptr;
	std::ostream *ostr = &std::cout;
	if(cfg.out_rom != "")
	{
		ofstr = new std::ofstream(cfg.out_rom);
		ostr = ofstr;
	}


	(*ostr) << "module " << cfg.entity_name << "\n";

	if(!cfg.local_params)
	{
		(*ostr) << "#(\n"
			<< "\tparameter FIRST_CHAR  = " << cfg.ch_first << ",\n"
			<< "\tparameter LAST_CHAR   = " << cfg.ch_last << ",\n"
			<< "\tparameter CHAR_PITCH  = " << cfg.target_pitch << ",\n"
			<< "\tparameter CHAR_WIDTH  = " << cfg.target_pitch * cfg.pitch_bits << ",\n"
			<< "\tparameter CHAR_HEIGHT = " << cfg.target_height << "\n"
			<< ")\n";
	}

	(*ostr) << "(\n"
		<< "\tinput wire [" << std::ceil(std::log2(cfg.ch_last)) - 1 << " : 0] in_char,\n"
		<< "\tinput wire [" << std::ceil(std::log2(cfg.target_pitch * cfg.pitch_bits)) - 1 << " : 0] in_x,\n"
		<< "\tinput wire [" << std::ceil(std::log2(cfg.target_height)) - 1 << " : 0] in_y,\n"
		<< "\toutput wire out_pixel\n"
		<< ");\n\n";

	if(cfg.local_params)
	{
		(*ostr) << "\n"
			<< "localparam FIRST_CHAR  = " << cfg.ch_first << ";\n"
			<< "localparam LAST_CHAR   = " << cfg.ch_last << ";\n"
			<< "localparam CHAR_PITCH  = " << cfg.target_pitch << ";\n"
			<< "localparam CHAR_WIDTH  = " << cfg.target_pitch * cfg.pitch_bits << ";\n"
			<< "localparam CHAR_HEIGHT = " << cfg.target_height << ";\n"
			<< "\n";
	}

	(*ostr) << "\nwire [0 : CHAR_WIDTH - 1] chars [0 : (LAST_CHAR - FIRST_CHAR) * CHAR_HEIGHT - 1];\n\n";


	// iterate characters
	for(std::size_t charidx = 0; charidx < fontbits.charbits.size(); ++charidx)
	{
		const CharBits& charbits = fontbits.charbits[charidx];

		(*ostr) << "\n// char number " << charbits.ch_num
			<< ": '" << static_cast<char>(charbits.ch_num) << "'"
			<< ", height: " << charbits.height
			<< ", width: " << charbits.width
			<< ", pitch: " << charbits.pitch
			<< ", bearing x: " << charbits.bearing_x
			<< ", bearing y: " << charbits.bearing_y
			<< ", left: " << charbits.left
			<< ", top: " << charbits.top
			<< "\n";

		// iterate lines
		for(std::size_t line = 0; line < charbits.lines.size(); ++line)
		{
			const std::vector<boost::dynamic_bitset<>>& linebits = charbits.lines[line];
			(*ostr) << "assign chars[" << std::setw(3) << charidx
				<< "*CHAR_HEIGHT + " << std::setw(3) << line << "] = ";
			(*ostr) << linebits.size()*cfg.pitch_bits << "'b";

			// iterate pitch
			for(std::size_t x = 0; x < linebits.size(); ++x)
				(*ostr) << linebits[x];

			(*ostr) << ";\n";
		}
	}


	(*ostr) << "\n\nwire [0 : CHAR_WIDTH - 1] line;\n"
		<< "assign line = chars[in_char*CHAR_HEIGHT + in_y];\n"
		<< "assign out_pixel = line[in_x];\n";

	(*ostr) << "\nendmodule" << std::endl;


	// clean up
	if(ofstr)
	{
		delete ofstr;
		ofstr = nullptr;
	}

	return true;
}
