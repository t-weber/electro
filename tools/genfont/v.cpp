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

	const int char_width = cfg.target_pitch * static_cast<int>(cfg.pitch_bits);
	const unsigned int num_chars = cfg.ch_last - cfg.ch_first;

	const unsigned int char_idx_bits = std::ceil(std::log2(num_chars));
	const unsigned int char_last_bits = std::ceil(std::log2(cfg.ch_last));
	const unsigned int char_width_bits = std::ceil(std::log2(char_width));
	const unsigned int char_height_bits = std::ceil(std::log2(cfg.target_height));

	if(!cfg.local_params)
	{
		(*ostr) << "#(\n"
			<< "\tparameter [" << char_last_bits - 1 << " : 0]"
			<< " FIRST_CHAR = " << cfg.ch_first << ",\n"
			<< "\tparameter LAST_CHAR   = " << cfg.ch_last << ",\n"
			<< "\tparameter NUM_CHARS   = " << num_chars << ",\n"
			<< "\tparameter CHAR_WIDTH  = " << char_width << ",\n"
			<< "\tparameter CHAR_HEIGHT = " << cfg.target_height << "\n"
			<< ")\n";
	}

	(*ostr) << "(\n";
	if(cfg.sync)
		(*ostr) << "\tinput wire in_clk,\n";
	(*ostr) << "\tinput wire [" << char_last_bits - 1 << " : 0] in_char,\n"
		<< "\tinput wire [" << char_width_bits - 1 << " : 0] in_x,\n"
		<< "\tinput wire [" << char_height_bits - 1 << " : 0] in_y,\n";

	if(!cfg.local_params)
		(*ostr) << "\n\toutput wire [0 : CHAR_WIDTH - 1'b1] out_line,\n";
	else
		(*ostr) << "\n\toutput wire [0 : " << char_width - 1 << "] out_line,\n";

	(*ostr) << "\toutput wire out_pixel\n"
		<< ");\n\n";

	if(cfg.local_params)
	{
		(*ostr) << "\n"
			<< "localparam [" << char_last_bits - 1 << " : 0]"
			<< " FIRST_CHAR = " << cfg.ch_first << ";\n"
			<< "localparam LAST_CHAR   = " << cfg.ch_last << ";\n"
			<< "localparam NUM_CHARS   = LAST_CHAR - FIRST_CHAR;\n"
			<< "localparam CHAR_WIDTH  = " << char_width << ";\n"
			<< "localparam CHAR_HEIGHT = " << cfg.target_height << ";\n"
			<< "\n";
	}

	if(cfg.sync)
		(*ostr) << "\nreg ";
	else
		(*ostr) << "\nwire ";
	(*ostr) << "[0 : CHAR_WIDTH - 1'b1] chars [0 : NUM_CHARS*CHAR_HEIGHT - 1'b1];\n\n";

	if(cfg.sync)
		(*ostr) << "\ninitial begin\n";

	// iterate characters
	for(std::size_t charidx = 0; charidx < fontbits.charbits.size(); ++charidx)
	{
		const CharBits& charbits = fontbits.charbits[charidx];

		(*ostr) << "\n";
		if(cfg.sync)
			(*ostr) << "\t";
		(*ostr) << "// char #" << charbits.ch_num
			<< std::hex << " (0x" << std::hex << charbits.ch_num << ")" << std::dec
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
			const CharBits::t_line& linebits = charbits.lines[line];

			if(!cfg.sync)
				(*ostr) << "assign ";
			else
				(*ostr) << "\t";

			(*ostr) << "chars[" << std::setw(3) << charidx
				<< "*CHAR_HEIGHT + " << std::setw(3) << line << "]";

			if(cfg.sync)
				(*ostr) << " <= ";
			else
				(*ostr) << " = ";

			(*ostr) << linebits.size()*cfg.pitch_bits << "'b";

			// iterate pitch
			for(std::size_t x = 0; x < linebits.size(); ++x)
				(*ostr) << linebits[x];

			(*ostr) << ";\n";
		}
	}

	if(cfg.sync)
		(*ostr) << "end\n";
	(*ostr) << "\n";


	(*ostr) << "\nwire [" << char_idx_bits - 1 << " : 0]    char_idx;\n"
		<< "wire [" << char_width_bits - 1 << " : 0]  xpix;\n"
		<< "wire [" << char_height_bits - 1 << " : 0] ypix;\n\n";

	if(cfg.sync)
	{
		(*ostr) << "reg [0 : CHAR_WIDTH - 1'b1] line;\n";
		(*ostr) << "reg pixel;\n";
	}
	else
	{
		(*ostr) << "wire [0 : CHAR_WIDTH - 1'b1] line;\n";
		(*ostr) << "wire pixel;\n";
	}

	if(cfg.check_bounds)
	{
		(*ostr) << "\nassign char_idx = in_char >= FIRST_CHAR && in_char < LAST_CHAR\n"
			<< "\t? in_char - FIRST_CHAR\n"
			<< "\t: " << char_idx_bits << "'b0;\n";

		(*ostr) << "\nassign xpix = in_x < CHAR_WIDTH ? in_x : "
			<< char_width_bits << "'b0;\n";
		(*ostr) << "assign ypix = in_y < CHAR_HEIGHT ? in_y : "
			<< char_height_bits << "'b0;\n";
	}
	else
	{
		(*ostr) << "\nassign char_idx = in_char - FIRST_CHAR;"
			<< "\nassign xpix = in_x;"
			<< "\nassign ypix = in_y;\n";
	}

	(*ostr) << "\nassign out_line = line;\n";
	(*ostr) << "assign out_pixel = pixel;\n";

	if(cfg.sync)
	{
		(*ostr) << "\n\nalways@(posedge in_clk) begin\n";

		(*ostr) << "\tline <= chars[char_idx*CHAR_HEIGHT + ypix];\n"
			<< "\tpixel <= line[xpix];\n";

		(*ostr) << "end\n";
	}
	else
	{
		(*ostr) << "\nassign line = chars[char_idx*CHAR_HEIGHT + ypix];\n"
			<< "assign pixel = line[xpix];\n";
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
