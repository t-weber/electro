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
 * output a vhdl file
 */
bool create_font_vhdl(const FontBits& fontbits, const Config& cfg)
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

	if(!cfg.local_params)
	{
		(*ostr) << "\tgeneric(\n"
			<< "\t\tconstant FIRST_CHAR  : natural := " << cfg.ch_first << ";\n"
			<< "\t\tconstant LAST_CHAR   : natural := " << cfg.ch_last << ";\n"
			<< "\t\tconstant CHAR_PITCH  : natural := " << cfg.target_pitch << ";\n"
			<< "\t\tconstant CHAR_WIDTH  : natural := " << cfg.target_pitch * cfg.pitch_bits << ";\n"
			<< "\t\tconstant CHAR_HEIGHT : natural := " << cfg.target_height << "\n"
			<< "\t);\n\n";
	}

	(*ostr) << "\tport(\n"
		<< "\t\tin_char : in std_logic_vector(" << std::ceil(std::log2(cfg.ch_last)) - 1 << " downto 0);\n"
		<< "\t\tin_x : in std_logic_vector(" << std::ceil(std::log2(cfg.target_pitch * cfg.pitch_bits)) - 1 << " downto 0);\n"
		<< "\t\tin_y : in std_logic_vector(" << std::ceil(std::log2(cfg.target_height)) - 1 << " downto 0);\n"
		<< "\t\tout_pixel : out std_logic\n"
		<< "\t);\n\n"
		<< "end entity;\n\n";

	(*ostr) << "\narchitecture " << cfg.entity_name << "_impl of " << cfg.entity_name << " is\n";

	if(cfg.local_params)
	{
		(*ostr) << "\n"
			<< "\tconstant FIRST_CHAR  : natural := " << cfg.ch_first << ";\n"
			<< "\tconstant LAST_CHAR   : natural := " << cfg.ch_last << ";\n"
			<< "\tconstant CHAR_PITCH  : natural := " << cfg.target_pitch << ";\n"
			<< "\tconstant CHAR_WIDTH  : natural := " << cfg.target_pitch * cfg.pitch_bits << ";\n"
			<< "\tconstant CHAR_HEIGHT : natural := " << cfg.target_height << ";\n"
			<< "\n";
	}

	(*ostr) << "\tsubtype t_line is std_logic_vector(0 to CHAR_WIDTH-1);\n"
		<< "\ttype t_char is array(0 to CHAR_HEIGHT-1) of t_line;\n"
		<< "\ttype t_chars is array(FIRST_CHAR to LAST_CHAR-1) of t_char;\n";

	(*ostr) << "\n\tconstant chars : t_chars :=\n\t(";


	// iterate characters
	for(const CharBits& charbits : fontbits.charbits)
	{
		(*ostr) << "\n\t\t-- char number " << charbits.ch_num
			<< ": '" << static_cast<char>(charbits.ch_num) << "'"
			<< ", height: " << charbits.height
			<< ", width: " << charbits.width
			<< ", pitch: " << charbits.pitch
			<< ", bearing x: " << charbits.bearing_x
			<< ", bearing y: " << charbits.bearing_y
			<< ", left: " << charbits.left
			<< ", top: " << charbits.top
			<< "\n";

		(*ostr) << "\t\t(\n";

		// iterate lines
		for(std::size_t line = 0; line < charbits.lines.size(); ++line)
		{
			const std::vector<boost::dynamic_bitset<>>& linebits = charbits.lines[line];
			(*ostr) << "\t\t\t\"";

			// iterate pitch
			for(std::size_t x = 0; x < linebits.size(); ++x)
				(*ostr) << linebits[x];

			(*ostr) << "\"";
			if(line < charbits.lines.size() - 1)
				(*ostr) << ",";
			(*ostr) << "\n";
		}

		(*ostr) << "\t\t)";
		if(charbits.ch_num < cfg.ch_last - 1)
			(*ostr) << ",";
		(*ostr) << "\n";
	}


	(*ostr) << "\n\t);\n";

	(*ostr) << "\nbegin\n";
	(*ostr) << "\n\tout_pixel <= chars(to_int(in_char))(to_int(in_y))(to_int(in_x))\n"
		<< "\t\twhen to_int(in_char) >= FIRST_CHAR and to_int(in_char) < LAST_CHAR\n"
		<< "\t\telse '0';\n";
	(*ostr) << "\nend architecture;" << std::endl;


	// clean up
	if(ofstr)
	{
		delete ofstr;
		ofstr = nullptr;
	}

	return true;
}
