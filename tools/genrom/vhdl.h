/**
 * generates vhdl rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_VHDL__
#define __GENROM_VHDL__


#include <string>
#include <iostream>


/**
 * generates a vhdl rom file
 */
std::string gen_rom_vhdl(std::istream& data, int max_line_len = 16,
	int num_ports = 2, bool fill_rom = true);


#endif
