/**
 * create a font rom
 * @author Tobias Weber
 * @date jan-2022, apr-2024
 * @license see 'LICENSE' file
 */

#include "genfont.h"

#include <iostream>
#include <fstream>
#include <iomanip>



/**
 * output an sv file
 */
bool create_font_sv(const FontBits& fontbits, const Config& cfg)
{
	std::ofstream *ofstr = nullptr;
	std::ostream *ostr = &std::cout;
	if(cfg.out_rom != "")
	{
		ofstr = new std::ofstream(cfg.out_rom);
		ostr = ofstr;
	}


	(*ostr) << "module " << cfg.entity_name << "\n";

	int char_width = cfg.target_pitch * static_cast<int>(cfg.pitch_bits);
	if(!cfg.local_params)
	{
		(*ostr) << "#(\n"
			<< "\tparameter FIRST_CHAR  = " << cfg.ch_first << ",\n"
			<< "\tparameter LAST_CHAR   = " << cfg.ch_last << ",\n"
			<< "\tparameter NUM_CHARS   = " << cfg.ch_last - cfg.ch_first << ",\n"
			<< "\tparameter CHAR_PITCH  = " << cfg.target_pitch << ",\n"
			<< "\tparameter CHAR_WIDTH  = " << char_width << ",\n"
			<< "\tparameter CHAR_HEIGHT = " << cfg.target_height << "\n"
			<< ")\n";
	}

	(*ostr) << "(\n"
		<< "\tinput wire [" << std::ceil(std::log2(cfg.ch_last)) - 1 << " : 0] in_char,\n"
		<< "\tinput wire [" << std::ceil(std::log2(char_width)) - 1 << " : 0] in_x,\n"
		<< "\tinput wire [" << std::ceil(std::log2(cfg.target_height)) - 1 << " : 0] in_y,\n"
		<< "\toutput wire out_pixel\n"
		<< ");\n\n";

	if(cfg.local_params)
	{
		(*ostr) << "\n"
			<< "localparam FIRST_CHAR  = " << cfg.ch_first << ";\n"
			<< "localparam LAST_CHAR   = " << cfg.ch_last << ";\n"
			<< "localparam NUM_CHARS   = LAST_CHAR - FIRST_CHAR;\n"
			<< "localparam CHAR_PITCH  = " << cfg.target_pitch << ";\n"
			<< "localparam CHAR_WIDTH  = " << char_width << ";\n"
			<< "localparam CHAR_HEIGHT = " << cfg.target_height << ";\n"
			<< "\n";
	}

	(*ostr) << "\nlogic [0 : NUM_CHARS*CHAR_HEIGHT - 1][0 : CHAR_WIDTH - 1] chars ="
		<< "\n{";


	// iterate characters
	for(const CharBits& charbits : fontbits.charbits)
	{
		(*ostr) << "\n\t// char number " << charbits.ch_num
			<< ": '" << static_cast<char>(charbits.ch_num) << "'"
			<< ", height: " << charbits.height
			<< ", width: " << charbits.width
			<< ", pitch: " << charbits.pitch
			<< ", bearing x: " << charbits.bearing_x
			<< ", bearing y: " << charbits.bearing_y
			<< ", left: " << charbits.left
			<< ", top: " << charbits.top
			<< "\n";

		//(*ostr) << "\t{\n";

		// iterate lines
		for(std::size_t line = 0; line < charbits.lines.size(); ++line)
		{
			const std::vector<boost::dynamic_bitset<>>& linebits = charbits.lines[line];
			(*ostr) << "\t" << linebits.size()*cfg.pitch_bits << "'b";

			// iterate pitch
			for(std::size_t x = 0; x < linebits.size(); ++x)
				(*ostr) << linebits[x];

			//if(line < charbits.lines.size() - 1)
			if(line < charbits.lines.size() - 1 || charbits.ch_num < cfg.ch_last - 1)
				(*ostr) << ",";
			(*ostr) << "\n";
		}

		/*(*ostr) << "\t}";
		if(charbits.ch_num < cfg.ch_last - 1)
			(*ostr) << ",";
		(*ostr) << "\n";*/
	}


	(*ostr) << "\n};\n";

	(*ostr) << "\nwire [0 : CHAR_WIDTH - 1] line;\n";

	if(cfg.check_bounds)
	{
		(*ostr) << "\nassign line = in_char < NUM_CHARS\n"
			<< "\t? chars[in_char*CHAR_HEIGHT + in_y]\n"
			<< "\t: CHAR_WIDTH'(1'b0);\n";

		(*ostr) << "\nassign out_pixel = in_x < CHAR_WIDTH\n"
			<< "\t? line[in_x]\n"
			<< "\t: 1'b0;\n";
	}
	else
	{
		(*ostr) << "assign line = chars[in_char*CHAR_HEIGHT + in_y];\n"
			<< "assign out_pixel = line[in_x];\n";
	}

	(*ostr) << "\nendmodule" << std::endl;


	// clean up
	if(ofstr)
	{
		delete ofstr;
		ofstr = nullptr;
	}

	return true;
}
