/**
 * reads in a text file, interpreting the numbers
 * @author Tobias Weber
 * @date 28 September, 2025
 * @license see 'LICENSE' file
 */

#include "text.h"

#include <string>
#include <iostream>
#include <fstream>
#include <sstream>


static t_words convert_line(std::string& line)
{
	t_words words;

	std::string::size_type pos = line.find('#');
	if(pos != std::string::npos)
		line = line.substr(0, pos);
	//std::cout << line << std::endl;

	std::istringstream istr(line);
	while(istr)
	{
		unsigned short i = 0;
		istr >> std::hex >> i;
		if(!istr)
			break;

		t_word dat(8, i);
		words.emplace_back(std::move(dat));
	}

	return words;
}


std::tuple<bool, t_words> convert_text(const std::filesystem::path& path)
{
	t_words words;

	std::ifstream ifstr(path);
	if(!ifstr)
	{
		std::cerr << "Cannot open \"" << path << "\" for reading." << std::endl;
		return std::make_tuple(false, words);
	}

	while(ifstr)
	{
		std::string line;
		if(!std::getline(ifstr, line))
			break;
		//std::cout << line << std::endl;

		t_words converted = convert_line(line);
		//words.append_range(converted);
		words.insert(words.end(), converted.cbegin(), converted.cend());
	}

	return std::make_tuple(true, words);
}
