/**
 * generates sv rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_SV__
#define __GENROM_SV__

#include "defs.h"

#include <string>
#include <iostream>


/**
 * generates an SV rom
 */
extern std::string gen_rom_sv(const Config& cfg);

#endif
