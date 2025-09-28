/**
 * reads in a text file, interpreting the numbers
 * @author Tobias Weber
 * @date 28 September, 2025
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_CONVTXT__
#define __GENROM_CONVTXT__

#include "defs.h"

#include <tuple>
#include <filesystem>


extern std::tuple<bool, t_words>
	convert_text(const std::filesystem::path& path);


#endif
