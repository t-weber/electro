/**
 * generates .v rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_V__
#define __GENROM_V__

#include "defs.h"

#include <string>
#include <iostream>


/**
 * generates a .v rom
 */
extern std::string gen_rom_v(const t_words& data, int max_line_len = 16,
	int num_ports = 2, bool direct_ports = false,
	bool fill_rom = true, bool print_chars = true,
	const std::string& module_name = "rom");

#endif
