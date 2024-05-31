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
 * output an optimised vhdl file
 */
bool create_font_vhdl_opt(const FontBits& fontbits, const Config& cfg)
{
	std::ofstream *ofstr = nullptr;
	std::ostream *ostr = &std::cout;
	if(cfg.out_rom != "")
	{
		ofstr = new std::ofstream(cfg.out_rom);
		ostr = ofstr;
	}


	(*ostr) << "library ieee;\n"
		<< "use ieee.std_logic_1164.all;\n"
		<< "use work.conv.all;\n\n";

	(*ostr) << "\nentity " << cfg.entity_name << " is\n";

	const int char_width = cfg.target_pitch * static_cast<int>(cfg.pitch_bits);
        const unsigned int char_last_bits = std::ceil(std::log2(cfg.ch_last));
        const unsigned int char_width_bits = std::ceil(std::log2(char_width));
        const unsigned int char_height_bits = std::ceil(std::log2(cfg.target_height));

	if(!cfg.local_params)
	{
		(*ostr) << "\tgeneric(\n"
			<< "\t\tconstant FIRST_CHAR  : natural := " << cfg.ch_first << ";\n"
			<< "\t\tconstant LAST_CHAR   : natural := " << cfg.ch_last << ";\n"
			<< "\t\tconstant CHAR_WIDTH  : natural := " << char_width << ";\n"
			<< "\t\tconstant CHAR_HEIGHT : natural := " << cfg.target_height << "\n"
			<< "\t);\n\n";
	}

	(*ostr) << "\tport(\n";
	if(cfg.sync)
		(*ostr) << "\t\tin_clk : in std_logic;\n";
	(*ostr) << "\t\tin_char : in std_logic_vector(" << char_last_bits - 1 << " downto 0);\n"
		<< "\t\tin_x : in std_logic_vector(" << char_width_bits - 1 << " downto 0);\n"
		<< "\t\tin_y : in std_logic_vector(" << char_height_bits - 1 << " downto 0);\n";

	if(!cfg.local_params)
		(*ostr) << "\n\t\tout_line : out std_logic_vector(0 to CHAR_WIDTH - 1);\n";
	else
		(*ostr) << "\n\t\tout_line : out std_logic_vector(0 to " << char_width - 1 << ");\n";

	(*ostr) << "\t\tout_pixel : out std_logic\n"
		<< "\t);\n\n"
		<< "end entity;\n\n";

	(*ostr) << "\narchitecture " << cfg.entity_name << "_impl of " << cfg.entity_name << " is\n";

	if(cfg.local_params)
	{
		(*ostr) << "\n"
			<< "\tconstant FIRST_CHAR  : natural := " << cfg.ch_first << ";\n"
			<< "\tconstant LAST_CHAR   : natural := " << cfg.ch_last << ";\n"
			<< "\tconstant CHAR_WIDTH  : natural := " << char_width << ";\n"
			<< "\tconstant CHAR_HEIGHT : natural := " << cfg.target_height << ";\n"
			<< "\n";
	}

	const unsigned int char_idx_bits = std::ceil(std::log2(cfg.ch_last - cfg.ch_first));
	const unsigned int line_idx_bits = std::ceil(std::log2((cfg.ch_last - cfg.ch_first) * cfg.target_height));

	(*ostr) << "\tsignal char_idx : std_logic_vector(" << char_idx_bits - 1 << " downto 0);\n";
	(*ostr) << "\tsignal line_idx : std_logic_vector(" << line_idx_bits - 1 << " downto 0);\n";

	(*ostr) << "\tsignal line : std_logic_vector(0 to " << char_width - 1 << ") := (others => '0');\n";


	(*ostr) << "\nbegin\n";


	(*ostr) << "\tchar_idx <= int_to_logvec(to_int(in_char) - FIRST_CHAR, " << char_idx_bits << ")";
	if(cfg.check_bounds)
	{
		(*ostr) << "\n\t\twhen to_int(in_char) >= FIRST_CHAR and to_int(in_char) < LAST_CHAR";
		(*ostr) << "\n\t\telse (others => '0')";
	}
	(*ostr) << ";\n";

	(*ostr) << "\tline_idx <= int_to_logvec(to_int(char_idx)*CHAR_HEIGHT + to_int(in_y), " << line_idx_bits << ");\n\n";


	if(cfg.sync)
	{
		(*ostr) << "\tprocess(in_clk) begin\n";
		(*ostr) << "\t\tif rising_edge(in_clk) then\n";

		(*ostr) << "\t\t\tcase line_idx is\n";

		// iterate lines
		for(const auto& [line, line_addrs] : fontbits.lines_opt)
		{
			// ignore default case with only zeros
			if(is_zero(line))
				continue;

			(*ostr) << "\t\t\t\twhen ";
			for(std::size_t idx = 0; idx < line_addrs.size(); ++idx)
			{
				(*ostr) << line_idx_bits << "x\"" << std::hex << line_addrs[idx] << "\"" << std::dec;
				if(idx < line_addrs.size() - 1)
					(*ostr) << " | ";
			}

			(*ostr) << " =>\n\t\t\t\t\tline <= \"" << line << "\";\n";
		}

		(*ostr) << "\t\t\t\twhen others =>\n\t\t\t\t\tline <= (others => '0');\n";
		(*ostr) << "\t\t\tend case;\n\n";


		(*ostr) << "\t\t\tout_line <= line;\n";

		if(cfg.check_bounds)
		{
			(*ostr) << "\t\t\tif to_int(in_char) >= FIRST_CHAR and to_int(in_char) < LAST_CHAR then\n"
				<< "\t\t\t\tout_pixel <= line(to_int(in_x));\n"
				<< "\t\t\telse\n"
				<< "\t\t\t\tout_pixel <= '0';\n"
				<< "\t\t\tend if;\n";
		}
		else
		{
			(*ostr) << "\t\t\tout_pixel <= line(to_int(in_x));\n";
		}


		(*ostr) << "\t\tend if;\n";
		(*ostr) << "\tend process;\n";
	}
	else
	{
		(*ostr) << "\twith line_idx select line <=\n";

		// iterate lines
		for(const auto& [line, line_addrs] : fontbits.lines_opt)
		{
			// ignore default case with only zeros
			if(is_zero(line))
				continue;

			(*ostr) << "\t\t\"" << line << "\" when ";

			for(std::size_t idx = 0; idx < line_addrs.size(); ++idx)
			{
				(*ostr) << line_idx_bits << "x\""  << std::hex << line_addrs[idx] << "\"" << std::dec;
				if(idx < line_addrs.size() - 1)
					(*ostr) << " | ";
				else
					(*ostr) << ",\n";
			}
		}

		(*ostr) << "\t\t(others => '0') when others;\n\n";


		(*ostr) << "\tout_line <= line;\n";

		if(cfg.check_bounds)
		{
			(*ostr) << "\tout_pixel <= line(to_int(in_x))\n"
				<< "\t\twhen to_int(in_char) >= FIRST_CHAR and to_int(in_char) < LAST_CHAR\n"
				<< "\t\telse '0';\n";
		}
		else
		{
			(*ostr) << "\tout_pixel <= line(to_int(in_x));\n";
		}
	}


	(*ostr) << "\nend architecture;" << std::endl;


	// clean up
	if(ofstr)
	{
		delete ofstr;
		ofstr = nullptr;
	}

	return true;
}
