/**
 * common code
 * @author Tobias Weber
 * @date 18-May-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_COMMON_H__
#define __GENROM_COMMON_H__

#include <cstdlib>


extern void test_bounds_check(
	std::size_t rom_len, std::size_t max_rom_len,
	bool& check_bounds);


#endif
