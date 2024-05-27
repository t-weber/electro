/**
 * generates vhdl rom files
 * @author Tobias Weber
 * @date 17-Jan-2024
 * @license see 'LICENSE' file
 */

#include "vhdl.h"
#include "common.h"

#include <string>
#include <iomanip>
#include <sstream>
#include <cmath>

#include <boost/algorithm/string.hpp>


/**
 * generates a vhdl rom
 */
std::string gen_rom_vhdl(const Config& cfg)
{
	// rom file
	std::string rom_vhdl = R"raw(library ieee;
use ieee.std_logic_1164.all;
--use ieee.math_real.all;
use work.conv.all;

entity %%MODULE_NAME%% is
	generic(
		constant NUM_PORTS : natural := %%NUM_PORTS%%;
		constant NUM_WORDS : natural := %%NUM_WORDS%%;
		constant ADDR_BITS : natural := %%ADDR_BITS%%;  -- natural(ceil(log2(real(NUM_WORDS))));
		constant WORD_BITS : natural := %%WORD_BITS%%
	);

	port(%%PORTS_DEF%%);
end entity;

architecture %%MODULE_NAME%%_impl of %%MODULE_NAME%% is
	subtype t_word is std_logic_vector(WORD_BITS - 1 downto 0);
	type t_words is array(0 to NUM_WORDS - 1) of t_word;

	constant words : t_words :=
	(
%%ROM_DATA%%
	);

begin
%%PORTS_ASSIGN%%

end architecture;)raw";


	// create data block
	std::size_t rom_len = 0;
	std::size_t cur_line_len = 0;

	// get word size
	typename t_word::size_type word_bits = 8;
	if(cfg.data.size())
		word_bits = cfg.data[0].size();

	std::ostringstream ostr_data;
	ostr_data << "\t\t";
	bool first_data = true;
	std::vector<char> chs;
	bool has_printables = false;

	// add a printable character to the comment
	auto add_char = [&chs, &has_printables](int ch)
	{
		if(std::isprint(ch))
		{
			chs.push_back(static_cast<char>(ch));
			has_printables = true;
		}
		else if(std::isspace(ch))
		{
			chs.push_back(' ');
		}
		else
		{
			chs.push_back('.');
		}
	};

	// print characters in a comment
	auto write_chars = [&chs, &has_printables, &ostr_data]()
	{
		if(has_printables)
		{
			ostr_data << " -- ";
			for(char c : chs)
				ostr_data << c;

			has_printables = false;
		}

		chs.clear();
	};

	for(const t_word& dat : cfg.data)
	{
		if(!first_data)
			ostr_data << ", ";

		if(cur_line_len >= cfg.max_line_len)
		{
			if(cfg.print_chars)
				write_chars();

			ostr_data << "\n\t\t";
			cur_line_len = 0;
		}

		if(word_bits % 4 == 0)
		{
			// print as hex
			ostr_data
				<< "x\""
				<< std::hex << std::setfill('0') << std::setw(word_bits/4)
				<< dat.to_ulong()
				<< "\"";
		}
		else
		{
			// print as binary
			ostr_data << "\"" << dat << "\"";
		}

		if(cfg.print_chars)
			add_char(static_cast<int>(dat.to_ulong()));

		first_data = false;
		++rom_len;
		++cur_line_len;
	}

	const std::size_t addr_bits = rom_len > 0
		? std::size_t(std::ceil(std::log2(double(rom_len))))
		: 0;

	const std::size_t max_rom_len = std::pow(2, addr_bits);

	// fill-up data block to maximum size
	if(cfg.fill_rom && rom_len > 0)
	{
		t_word fill_data(word_bits, 0x00);
		for(; rom_len < max_rom_len; ++rom_len)
		{
			if(!first_data)
				ostr_data << ", ";

			if(cur_line_len >= cfg.max_line_len)
			{
				if(cfg.print_chars)
					write_chars();

				ostr_data << "\n\t\t";
				cur_line_len = 0;
			}

			if(word_bits % 4 == 0)
			{
				// print as hex
				ostr_data
					<< "x\""
					<< std::hex << std::setfill('0') << std::setw(word_bits/4)
					<< fill_data.to_ulong()
					<< "\"";
			}
			else
			{
				// print as binary
				ostr_data << "\"" << fill_data << "\"";
			}

			first_data = false;
			++cur_line_len;
		}
	}

	bool check_bounds = cfg.check_bounds;
	test_bounds_check(rom_len, max_rom_len, check_bounds);

	if(cfg.print_chars)
		write_chars();

	// fill in missing rom data fields
	boost::replace_all(rom_vhdl, "%%MODULE_NAME%%", cfg.module_name);
	if(cfg.fill_rom)
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", "2**" + std::to_string(addr_bits));
	else
		boost::replace_all(rom_vhdl, "%%NUM_WORDS%%", std::to_string(rom_len));
	boost::replace_all(rom_vhdl, "%%NUM_PORTS%%", std::to_string(cfg.num_ports));
	boost::replace_all(rom_vhdl, "%%WORD_BITS%%", std::to_string(word_bits));
	boost::replace_all(rom_vhdl, "%%ADDR_BITS%%", std::to_string(addr_bits));
	boost::replace_all(rom_vhdl, "%%ROM_DATA%%", ostr_data.str());

	const std::string proc_end = "\nend if;\nend process;\n";
	auto proc_begin = [](int port_nr = -1) -> std::string
	{
		if(port_nr < 0)
			return "process(in_clk) begin\nif rising_edge(in_clk) then\n";

		std::ostringstream ostr;
		ostr << "process(in_clk_" << port_nr << ") begin\n";
		ostr << "if rising_edge(in_clk_" << port_nr << ") then\n";
		return ostr.str();
	};

	if(cfg.direct_ports && cfg.num_ports == 1)
	{
		// only one port
		std::ostringstream ostrPorts;

		ostrPorts << "\n";
		if(cfg.sync)
			ostrPorts << "\t\tin_clk   : in std_logic;\n";
		ostrPorts << "\t\tin_addr  : in  std_logic_vector(ADDR_BITS - 1 downto 0);\n";
		ostrPorts << "\t\tout_data : out std_logic_vector(WORD_BITS - 1 downto 0)\n";
		ostrPorts << "\t";

		boost::replace_all(rom_vhdl, "%%PORTS_DEF%%", ostrPorts.str());

		boost::replace_all(rom_vhdl, "%%PORTS_ASSIGN%%", check_bounds
			? proc_begin() + "\tout_data <= words(to_int(in_addr)) when to_int(in_addr) < NUM_WORDS else (others => '0');" + proc_end
			: proc_begin() + "\tout_data <= words(to_int(in_addr));" + proc_end);
	}
	else if(cfg.direct_ports && cfg.num_ports > 1)
	{
		// iterate ports directly
		std::ostringstream ostrPorts, ostrAssign;

		ostrPorts << "\n";
		for(std::size_t port = 0; port < cfg.num_ports; ++port)
		{
			if(cfg.sync)
				ostrPorts << "\t\tin_clk_" << (port+1) << "   : in  std_logic;\n";
			ostrPorts << "\t\tin_addr_" << (port+1) << "  : in  std_logic_vector(ADDR_BITS - 1 downto 0);\n";
			ostrPorts << "\t\tout_data_" << (port+1) << " : out std_logic_vector(WORD_BITS - 1 downto 0)";

			if(check_bounds)
			{
				ostrAssign << proc_begin(port+1)
					<< "\tout_data_" << (port+1)
					<< " <= words(to_int(in_addr_" << (port+1)<< "))"
					<< "\n\t\twhen to_int(in_addr_" << (port+1)<< ") < NUM_WORDS"
					<< "\n\t\telse (others => '0');"
					<< proc_end;
			}
			else
			{
				ostrAssign << proc_begin(port+1)
					<< "\tout_data_" << (port+1)
					<< " <= words(to_int(in_addr_" << (port+1)<< "));"
					<< proc_end;
			}

			if(port + 1 < cfg.num_ports)
			{
				ostrPorts << ";";
				ostrAssign << "\n";
			}
			ostrPorts << "\n\n";
		}
		ostrPorts << "\t";

		boost::replace_all(rom_vhdl, "%%PORTS_DEF%%", ostrPorts.str());
		boost::replace_all(rom_vhdl, "%%PORTS_ASSIGN%%", ostrAssign.str());
	}
	else
	{
		// rom generic port definitions
		std::string rom_ports_vhdl;
		if(cfg.sync)
		{
			rom_ports_vhdl = R"raw(
		in_clk  :  in t_logicarray(0 to NUM_PORTS - 1);
		in_addr  : in  t_logicvecarray(0 to NUM_PORTS - 1)(ADDR_BITS - 1 downto 0);
		out_data : out t_logicvecarray(0 to NUM_PORTS - 1)(WORD_BITS - 1 downto 0)
	)raw";
		}
		else
		{
			rom_ports_vhdl = R"raw(
		in_addr  : in  t_logicvecarray(0 to NUM_PORTS - 1)(ADDR_BITS - 1 downto 0);
		out_data : out t_logicvecarray(0 to NUM_PORTS - 1)(WORD_BITS - 1 downto 0)
	)raw";
		}


		// rom generic port assignment
		std::string rom_ports_assign_vhdl;

		if(check_bounds)
		{
			if(cfg.sync)
			{
				rom_ports_assign_vhdl = R"raw(
	gen_ports : for portidx in 0 to NUM_PORTS - 1 generate
	begin
		process(in_clk(portidx)) begin
			if rising_edge(in_clk(portidx)) then
				out_data(portidx) <= words(to_int(in_addr(portidx)))
					when to_int(in_addr(portidx)) < NUM_WORDS
					else (others => '0');
			end if;
		end process;
	end generate;)raw";
			}
			else
			{
				rom_ports_assign_vhdl = R"raw(
	gen_ports : for portidx in 0 to NUM_PORTS - 1 generate
	begin
		out_data(portidx) <= words(to_int(in_addr(portidx)))
			when to_int(in_addr(portidx)) < NUM_WORDS
			else (others => '0');
	end generate;)raw";
			}
		}
		else
		{
			if(cfg.sync)
			{
				rom_ports_assign_vhdl = R"raw(
	gen_ports : for portidx in 0 to NUM_PORTS - 1 generate
	begin
		process(in_clk(portidx)) begin
			if rising_edge(in_clk(portidx)) then
				out_data(portidx) <= words(to_int(in_addr(portidx)));
			end if;
		end process;
	end generate;)raw";
			}
			else
			{
				rom_ports_assign_vhdl = R"raw(
	gen_ports : for portidx in 0 to NUM_PORTS - 1 generate
	begin
		out_data(portidx) <= words(to_int(in_addr(portidx)));
	end generate;)raw";
			}
		}


		// generate generic ports array
		boost::replace_all(rom_vhdl, "%%PORTS_DEF%%", rom_ports_vhdl);
		boost::replace_all(rom_vhdl, "%%PORTS_ASSIGN%%", rom_ports_assign_vhdl);
	}

	return rom_vhdl;
}
