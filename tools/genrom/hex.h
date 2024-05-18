/**
 * generates a hex dump
 * @author Tobias Weber
 * @date 3-Feb-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_HEX__
#define __GENROM_HEX__

#include "defs.h"

#include <string>
#include <iostream>


/**
 * generates an hex dump
 */
extern std::string gen_rom_hex(const Config& cfg);

#endif
