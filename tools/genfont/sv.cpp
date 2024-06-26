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

	const int char_width = cfg.target_pitch * static_cast<int>(cfg.pitch_bits);
	const unsigned int num_chars = cfg.ch_last - cfg.ch_first;

	const unsigned int char_idx_bits = std::ceil(std::log2(num_chars));
	const unsigned int char_last_bits = std::ceil(std::log2(cfg.ch_last));
	const unsigned int char_width_bits = std::ceil(std::log2(char_width));
	const unsigned int char_height_bits = std::ceil(std::log2(cfg.target_height));

	if(!cfg.local_params)
	{
		(*ostr) << "#(\n"
			<< "\tparameter FIRST_CHAR  = " << cfg.ch_first << ",\n"
			<< "\tparameter LAST_CHAR   = " << cfg.ch_last << ",\n"
			<< "\tparameter NUM_CHARS   = LAST_CHAR - FIRST_CHAR"
				<< " /* " << num_chars << " */,\n"
			<< "\tparameter CHAR_WIDTH  = " << char_width << ",\n"
			<< "\tparameter CHAR_HEIGHT = " << cfg.target_height << ",\n\n";

		(*ostr) << "\tparameter CHAR_IDX_BITS    = $clog2(NUM_CHARS)"
				<< " /* " << char_idx_bits << " */,\n"
			<< "\tparameter CHAR_LAST_BITS   = $clog2(LAST_CHAR)"
				<< " /* " << char_last_bits << " */,\n"
			<< "\tparameter CHAR_WIDTH_BITS  = $clog2(CHAR_WIDTH)"
				<< " /* " << char_width_bits << " */,\n"
			<< "\tparameter CHAR_HEIGHT_BITS = $clog2(CHAR_HEIGHT)"
				<< " /* " << char_height_bits << " */\n"
			<< ")\n";
	}

	(*ostr) << "(\n";
	if(cfg.sync)
		(*ostr) << "\tinput wire in_clk,\n";

	if(!cfg.local_params)
	{
		(*ostr) << "\tinput wire [CHAR_LAST_BITS - 1 : 0] in_char,\n"
			<< "\tinput wire [CHAR_WIDTH_BITS - 1 : 0] in_x,\n"
			<< "\tinput wire [CHAR_HEIGHT_BITS - 1 : 0] in_y,\n";

		(*ostr) << "\n\toutput wire [0 : CHAR_WIDTH - 1] out_line,\n";
	}
	else
	{
		(*ostr) << "\tinput wire [" << char_last_bits - 1 << " : 0] in_char,\n"
			<< "\tinput wire [" << char_width_bits - 1 << " : 0] in_x,\n"
			<< "\tinput wire [" << char_height_bits - 1 << " : 0] in_y,\n";

		(*ostr) << "\n\toutput wire [0 : " << char_width - 1 << "] out_line,\n";
	}

	(*ostr) << "\toutput wire out_pixel\n"
		<< ");\n\n";

	if(cfg.local_params)
	{
		(*ostr) << "\n"
			<< "localparam FIRST_CHAR       = " << cfg.ch_first << ";\n"
			<< "localparam LAST_CHAR        = " << cfg.ch_last << ";\n"
			<< "localparam NUM_CHARS        = LAST_CHAR - FIRST_CHAR"
				<< " /* " << num_chars << " */;\n"
			<< "localparam CHAR_WIDTH       = " << char_width << ";\n"
			<< "localparam CHAR_HEIGHT      = " << cfg.target_height << ";\n"
			<< "localparam CHAR_IDX_BITS    = $clog2(NUM_CHARS)"
				<< " /* " << char_idx_bits << " */;\n"
			<< "localparam CHAR_WIDTH_BITS  = $clog2(CHAR_WIDTH)"
				<< " /* " << char_width_bits << " */;\n"
			<< "localparam CHAR_HEIGHT_BITS = $clog2(CHAR_HEIGHT)"
				<< " /* " << char_height_bits << " */;\n"
			<< "\n";
	}

	(*ostr) << "\nlogic [0 : NUM_CHARS*CHAR_HEIGHT - 1][0 : CHAR_WIDTH - 1] chars ="
		<< "\n{";


	// iterate characters
	for(const CharBits& charbits : fontbits.charbits)
	{
		(*ostr) << "\n\t// char #" << charbits.ch_num
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
			(*ostr) << "\t" << linebits.size()*cfg.pitch_bits << "'b";

			// iterate pitch
			for(std::size_t x = 0; x < linebits.size(); ++x)
				(*ostr) << linebits[x];

			//if(line < charbits.lines.size() - 1)
			if(line < charbits.lines.size() - 1 || charbits.ch_num < cfg.ch_last - 1)
				(*ostr) << ",";
			(*ostr) << "\n";
		}
	}

	(*ostr) << "\n};\n\n";


	(*ostr) << "\nwire [CHAR_IDX_BITS - 1 : 0]    char_idx;\n"
		<< "wire [CHAR_WIDTH_BITS - 1 : 0]  xpix;\n"
		<< "wire [CHAR_HEIGHT_BITS - 1 : 0] ypix;\n";

	(*ostr) << "\nlogic [0 : CHAR_WIDTH - 1] line;\n"
		<< "logic pixel;\n";

	if(cfg.check_bounds)
	{
		(*ostr) << "\nassign char_idx = in_char >= FIRST_CHAR && in_char < LAST_CHAR\n"
			<< "\t? CHAR_IDX_BITS'(in_char - FIRST_CHAR)\n"
			<< "\t: CHAR_IDX_BITS'(1'b0);\n";

		(*ostr) << "\nassign xpix = in_x < CHAR_WIDTH ? in_x : CHAR_WIDTH_BITS'(1'b0);\n";
		(*ostr) << "assign ypix = in_y < CHAR_HEIGHT ? in_y : CHAR_HEIGHT_BITS'(1'b0);\n\n";
	}
	else
	{
		(*ostr) << "\nassign char_idx = CHAR_IDX_BITS'(in_char - FIRST_CHAR);"
			<< "\nassign xpix = in_x;"
			<< "\nassign ypix = in_y;\n";
	}

        (*ostr) << "\nassign out_line = line;\n";
        (*ostr) << "assign out_pixel = pixel;\n\n";

	if(cfg.sync)
	{
		(*ostr) << "\nalways_ff@(posedge in_clk) begin\n";

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
