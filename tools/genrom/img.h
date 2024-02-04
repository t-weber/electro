/**
 * reads an image
 * @author Tobias Weber
 * @date 4-Feb-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_READIMG__
#define __GENROM_READIMG__

#include "defs.h"

#include <tuple>
#include <filesystem>


extern std::tuple<std::size_t, std::size_t, std::size_t, t_words>
	read_jpg(const std::filesystem::path& path);

extern std::tuple<std::size_t, std::size_t, std::size_t, t_words>
	read_png(const std::filesystem::path& path);


#endif
