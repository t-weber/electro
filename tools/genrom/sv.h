/**
 * generates sv rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_SV__
#define __GENROM_SV__


#include <string>
#include <iostream>


/**
 * generates an SV rom file
 */
std::string gen_rom_sv(std::istream& data, int max_line_len = 16,
	int num_ports = 2, bool fill_rom = true);

#endif
