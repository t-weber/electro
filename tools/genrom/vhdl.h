/**
 * generates vhdl rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_VHDL__
#define __GENROM_VHDL__

#include "defs.h"

#include <string>
#include <iostream>


/**
 * generates a vhdl rom
 */
extern std::string gen_rom_vhdl(const Config& cfg);


#endif
