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

	(*ostr) << "\tsubtype t_line is std_logic_vector(0 to CHAR_WIDTH - 1);\n"
		<< "\ttype t_char is array(0 to CHAR_HEIGHT - 1) of t_line;\n"
		<< "\ttype t_chars is array(FIRST_CHAR to LAST_CHAR - 1) of t_char;\n";


	// iterate characters
	(*ostr) << "\n\tconstant chars : t_chars :=\n\t(";

	for(const CharBits& charbits : fontbits.charbits)
	{
		(*ostr) << "\n\t\t-- char #" << charbits.ch_num
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

		(*ostr) << "\t\t(\n";

		// iterate lines
		for(std::size_t line = 0; line < charbits.lines.size(); ++line)
		{
			const CharBits::t_line& linebits = charbits.lines[line];
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

	(*ostr) << "\n\t);\n\n";


	(*ostr) << "\tsignal ch   : std_logic_vector(" << char_last_bits - 1 << " downto 0);\n"
		<< "\tsignal xpix : std_logic_vector(" << char_width_bits - 1 << " downto 0);\n"
		<< "\tsignal ypix : std_logic_vector(" << char_height_bits - 1 << " downto 0);\n";

	(*ostr) << "\nbegin\n\n";

	if(cfg.check_bounds)
	{
		(*ostr) << "\tch <= in_char"
			<< " when to_int(in_char) >= FIRST_CHAR and to_int(in_char) < LAST_CHAR\n"
			<< "\t\telse nat_to_logvec(FIRST_CHAR, ch'length);\n\n";

		(*ostr) << "\txpix <= in_x"
			<< " when to_int(in_x) < CHAR_WIDTH\n"
			<< "\t\telse (others => '0');\n\n";

		(*ostr) << "\typix <= in_y"
			<< " when to_int(in_y) < CHAR_HEIGHT\n"
			<< "\t\telse (others => '0');\n\n";
	}
	else
	{
		(*ostr) << "\tch <= in_char;\n"
			<< "\txpix <= in_x;\n"
			<< "\typix <= in_y;\n\n";
	}


	if(cfg.sync)
	{
		(*ostr) << "\tprocess(in_clk) begin\n"
			<< "\t\tif rising_edge(in_clk) then\n";

		(*ostr) << "\t\t\tout_line <= chars(to_int(ch))(to_int(ypix));\n"
			<< "\t\t\tout_pixel <= chars(to_int(ch))(to_int(ypix))(to_int(xpix));\n";

		(*ostr) << "\t\tend if;\n"
			<< "\tend process;\n";
	}
	else
	{
		(*ostr) << "\n\tout_line <= chars(to_int(ch))(to_int(ypix));\n"
			<< "\tout_pixel <= chars(to_int(ch))(to_int(ypix))(to_int(xpix));\n";
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
