/**
 * basic type definitions
 * @author Tobias Weber
 * @date 4-Feb-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENROM_DEFS__
#define __GENROM_DEFS__

#include <vector>
#include <boost/dynamic_bitset.hpp>


using t_word = boost::dynamic_bitset<>;
using t_words = std::vector<t_word>;


struct Config
{
	t_words data{};

	bool direct_ports = false;
	std::size_t num_ports = 2;

	std::size_t max_line_len = 16;

	bool fill_rom = true;
	bool print_chars = true;
	bool check_bounds = true;
	bool sync = false;

	std::string module_name = "rom";
};


#endif
