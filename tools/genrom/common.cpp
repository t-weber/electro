/**
 * common code
 * @author Tobias Weber
 * @date 18-May-2024
 * @license see 'LICENSE' file
 */

#include "common.h"
#include <iostream>


void test_bounds_check(std::size_t rom_len, std::size_t max_rom_len, bool& check_bounds)
{
	if(rom_len == max_rom_len && check_bounds)
	{
		check_bounds = false;

		std::cerr << "Info: ROM length uses full address range, "
			<< "disabling bounds check."
			<< std::endl;
	}
	else if(rom_len > max_rom_len)
	{
		std::cerr << "Error: ROM length exceeds address range."
			<< std::endl;
	}
	else if(rom_len < max_rom_len && !check_bounds)
	{
		std::cerr << "Warning: ROM length does not use full address range, "
			<< "please enable bounds checks."
			<< std::endl;
	}
}
