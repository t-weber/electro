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


static t_words convert_line(std::string& line, int word_bits = 8)
{
	t_words words;

	std::string::size_type pos = line.find('#');
	if(pos != std::string::npos)
		line = line.substr(0, pos);
	//std::cout << line << std::endl;

	std::istringstream istr(line);
	while(istr)
	{
		t_word dat(word_bits, 0);

		for(int byte = 0; byte < word_bits/8; ++byte)
		{
			unsigned short i = 0;
			istr >> std::hex >> i;
			if(!istr)
				break;

			if(byte != 0)
				dat <<= 8;
			dat |= t_word(8, i);
		}

		if(!istr)
			break;

		//std::cout << "read line: " << dat << std::endl;
		words.emplace_back(std::move(dat));
	}

	return words;
}


std::tuple<bool, t_words> convert_text(
	const std::filesystem::path& path, int word_bits)
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

		t_words converted = convert_line(line, word_bits);
		//words.append_range(converted);
		words.insert(words.end(), converted.cbegin(), converted.cend());
	}

	return std::make_tuple(true, words);
}
