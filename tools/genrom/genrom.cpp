/**
 * generates rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include <string>
#include <iomanip>
#include <iostream>
#include <fstream>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


std::string gen_rom_vhdl(std::istream& data, int max_line_len = 16)
{
	// rom file
	std::string rom_vhdl = R"raw(library ieee;
use ieee.std_logic_1164.all;
use work.conv.all;

entity rom is
	generic(
		constant num_ports    : natural := %%NUM_PORTS%%;
		constant num_addrbits : natural := %%ADDR_BITS%%;
		constant num_wordbits : natural := %%WORD_BITS%%;
		constant num_words    : natural := 2**%%ADDR_BITS%%
	);

	port(
		in_addr  : in  t_logicvecarray(0 to num_ports-1)(num_addrbits-1 downto 0);
		out_word : out t_logicvecarray(0 to num_ports-1)(num_wordbits-1 downto 0)
	);
end entity;

architecture rom_impl of rom is
	subtype t_word is std_logic_vector(num_wordbits-1 downto 0);
	type t_words is array(0 to num_words-1) of t_word;

	signal words : t_words :=
	(
%%ROM_DATA%%
	);

begin
	gen_ports : for portidx in 0 to num_ports-1 generate
	begin
		out_word(portidx) <= words(to_int(in_addr(portidx)));
	end generate;

end architecture;
)raw";


	// create data block
	std::size_t rom_len = 0;
	int cur_line_len = 0;

	std::ostringstream ostr_data;
	ostr_data << "\t\t";
	bool first_data = true;
	while(!!data)
	{
		int ch = data.get();
		if(ch == std::istream::traits_type::eof())
			break;

		if(!first_data)
			ostr_data << ", ";

		if(cur_line_len >= max_line_len)
		{
			ostr_data << "\n\t\t";
			cur_line_len = 0;
		}

		ostr_data
			<< "x\""
			<< std::hex << std::setfill('0') << std::setw(2)
			<< static_cast<unsigned int>(ch)
			<< "\"";
		first_data = false;

		++rom_len;
		++cur_line_len;
	}

	std::size_t addr_bits = std::size_t(std::ceil(std::log2(double(rom_len))));
	std::size_t max_rom_len = std::pow(2, addr_bits);

	// fill-up data block to maximum size
	unsigned int fill_data = 0x00;
	for(; rom_len < max_rom_len; ++rom_len)
	{
		if(!first_data)
			ostr_data << ", ";

		if(cur_line_len >= max_line_len)
		{
			ostr_data << "\n\t\t";
			cur_line_len = 0;
		}

		ostr_data
			<< "x\""
			<< std::hex << std::setfill('0') << std::setw(2)
			<< fill_data
			<< "\"";
		first_data = false;

		++cur_line_len;
	}


	// fill in missing rom data fields
	boost::replace_all(rom_vhdl, "%%NUM_PORTS%%", std::to_string(2));
	boost::replace_all(rom_vhdl, "%%WORD_BITS%%", std::to_string(8));
	boost::replace_all(rom_vhdl, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_vhdl, "%%ROM_DATA%%", ostr_data.str());

	return rom_vhdl;
}


int main(int argc, char** argv)
{
	if(argc < 3)
	{
		std::cout << "Usage: " << argv[0] << " <input data> <output file>" << std::endl;
		return -1;
	}

	std::ifstream ifstr(argv[1]);
	if(!ifstr)
	{
		std::cerr << "Cannot open input " << argv[1] << "." << std::endl;
		return -1;
	}

	std::ofstream ofstr(argv[2]);
	if(!ofstr)
	{
		std::cerr << "Cannot open output " << argv[2] << "." << std::endl;
		return -1;
	}

	ofstr << gen_rom_vhdl(ifstr) << std::endl;
	return 0;
}
