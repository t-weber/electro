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

	(*ostr) << "(\n";
	if(cfg.sync)
		(*ostr) << "\tinput wire in_clk,\n";
	(*ostr) << "\tinput wire [" << std::ceil(std::log2(cfg.ch_last)) - 1 << " : 0] in_char,\n"
		<< "\tinput wire [" << std::ceil(std::log2(char_width)) - 1 << " : 0] in_x,\n"
		<< "\tinput wire [" << std::ceil(std::log2(cfg.target_height)) - 1 << " : 0] in_y,\n";

	if(!cfg.local_params)
		(*ostr) << "\n\toutput wire [0 : CHAR_WIDTH - 1] out_line,\n";
	else
		(*ostr) << "\n\toutput wire [0 : " << char_width - 1 << "] out_line,\n";

	(*ostr) << "\toutput wire out_pixel\n"
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

	if(cfg.sync)
		(*ostr) << "\nreg ";
	else
		(*ostr) << "\nwire ";
	(*ostr) << "[0 : CHAR_WIDTH - 1] chars [0 : NUM_CHARS*CHAR_HEIGHT - 1];\n\n";

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
			const std::vector<boost::dynamic_bitset<>>& linebits = charbits.lines[line];

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


	const unsigned int char_idx_bits = std::ceil(std::log2(cfg.ch_last - cfg.ch_first));
	(*ostr) << "\nwire [" << char_idx_bits - 1 << " : 0] char_idx;\n";

	if(cfg.sync)
	{
		(*ostr) << "reg [0 : CHAR_WIDTH - 1] line;\n";
		(*ostr) << "reg pixel;\n";
	}
	else
	{
		(*ostr) << "wire [0 : CHAR_WIDTH - 1] line;\n";
		(*ostr) << "wire pixel;\n";
	}

	if(cfg.check_bounds)
	{
		(*ostr) << "\nassign char_idx = in_char >= FIRST_CHAR && in_char < LAST_CHAR\n"
			<< "\t? in_char - FIRST_CHAR\n"
			<< "\t: " << char_idx_bits << "'b0;\n\n";
	}
	else
	{
		(*ostr) << "\nassign char_idx = in_char - FIRST_CHAR;\n";
	}

	(*ostr) << "assign out_line = line;\n";
	(*ostr) << "assign out_pixel = pixel;\n";

	if(cfg.check_bounds)
	{
		if(cfg.sync)
		{
			(*ostr) << "\n\nalways@(posedge in_clk) begin\n";

			(*ostr) << "\tline <= char_idx < NUM_CHARS\n"
				<< "\t\t? chars[char_idx*CHAR_HEIGHT + in_y]\n"
				<< "\t\t: " << char_width << "'b0;\n";

			(*ostr) << "\n\tpixel <= in_x < CHAR_WIDTH && char_idx < NUM_CHARS\n"
				<< "\t\t? chars[char_idx*CHAR_HEIGHT + in_y][in_x]\n"
				<< "\t\t: 1'b0;\n";

			(*ostr) << "end\n";
		}
		else
		{
			(*ostr) << "\nassign line = char_idx < NUM_CHARS\n"
				<< "\t? chars[char_idx*CHAR_HEIGHT + in_y]\n"
				<< "\t: " << char_width << "'b0;\n";

			(*ostr) << "\nassign pixel = in_x < CHAR_WIDTH\n"
				<< "\t? line[in_x]\n"
				<< "\t: 1'b0;\n";
		}
	}
	else
	{
		if(cfg.sync)
		{
			(*ostr) << "\n\nalways@(posedge in_clk) begin\n";

			(*ostr) << "\tline <= chars[char_idx*CHAR_HEIGHT + in_y];\n"
				<< "\tpixel <= chars[char_idx*CHAR_HEIGHT + in_y][in_x];\n";

			(*ostr) << "end\n";
		}
		else
		{
			(*ostr) << "\nassign line = chars[char_idx*CHAR_HEIGHT + in_y];\n"
				<< "assign pixel = line[in_x];\n";
		}
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
