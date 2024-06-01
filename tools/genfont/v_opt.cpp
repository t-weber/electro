/**
 * create a font rom
 * @author Tobias Weber
 * @date may-2024
 * @license see 'LICENSE' file
 */

#include "genfont.h"
#include "helpers.h"

#include <iostream>
#include <fstream>
#include <iomanip>



/**
 * output an optimised v file
 */
bool create_font_v_opt(const FontBits& fontbits, const Config& cfg)
{
	if(!cfg.sync)
		std::cerr << "Warning: Implicitly enabling synchronous design." << std::endl;

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
			<< "\tparameter CHAR_WIDTH  = " << char_width << ",\n"
			<< "\tparameter CHAR_HEIGHT = " << cfg.target_height << "\n"
			<< ")\n";
	}

	(*ostr) << "(\n";
	(*ostr) << "\tinput wire in_clk,\n";
	(*ostr) << "\tinput wire [" << std::ceil(std::log2(cfg.ch_last)) - 1 << " : 0] in_char,\n"
		<< "\tinput wire [" << std::ceil(std::log2(char_width)) - 1 << " : 0] in_x,\n"
		<< "\tinput wire [" << std::ceil(std::log2(cfg.target_height)) - 1 << " : 0] in_y,\n";

	if(!cfg.local_params)
		(*ostr) << "\n\toutput wire [0 : CHAR_WIDTH - 1'b1] out_line,\n";
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
			<< "localparam CHAR_WIDTH  = " << char_width << ";\n"
			<< "localparam CHAR_HEIGHT = " << cfg.target_height << ";\n"
			<< "\n";
	}


	const unsigned int char_idx_bits = std::ceil(std::log2(cfg.ch_last - cfg.ch_first));
	const unsigned int line_idx_bits = std::ceil(std::log2((cfg.ch_last - cfg.ch_first) * cfg.target_height));

	(*ostr) << "\nwire [" << char_idx_bits - 1 << " : 0] char_idx;\n";
	(*ostr) << "wire [" << line_idx_bits - 1 << " : 0] line_idx;\n";

	(*ostr) << "reg [0 : CHAR_WIDTH - 1'b1] line;\n";
	(*ostr) << "reg pixel;\n";

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

	(*ostr) << "assign line_idx = char_idx*CHAR_HEIGHT + in_y;\n";
	(*ostr) << "assign out_line = line;\n";
	(*ostr) << "assign out_pixel = pixel;\n";

	// create process
	(*ostr) << "\n\nalways@(posedge in_clk) begin\n";
	(*ostr) << "\tcase(line_idx)\n";

	// iterate lines
	for(const auto& [line, line_addrs] : fontbits.lines_opt)
	{
		// ignore default case with only zeros
		if(is_zero(line))
			continue;

		(*ostr) << "\t\t";
		for(std::size_t idx = 0; idx < line_addrs.size(); ++idx)
		{
			(*ostr) << line_idx_bits << "'h"
				<< std::hex << line_addrs[idx] << std::dec;
			if(idx < line_addrs.size() - 1)
				(*ostr) << ", ";
		}

		(*ostr) << ": line <= " << char_width << "'b" << line << ";\n";
	}

	(*ostr) << "\t\tdefault: line <= " << char_width << "'b0;\n";
	(*ostr) << "\tendcase\n";

	if(cfg.check_bounds)
	{
		(*ostr) << "\n\tpixel <= in_x < CHAR_WIDTH\n"
			<< "\t\t? line[in_x]\n"
			<< "\t\t: 1'b0;\n";
	}
	else
	{
		(*ostr) << "\n\tpixel <= line[in_x];\n";
	}

	(*ostr) << "end\n";


	(*ostr) << "\nendmodule" << std::endl;


	// clean up
	if(ofstr)
	{
		delete ofstr;
		ofstr = nullptr;
	}

	return true;
}
