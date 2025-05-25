/**
 * generate tones
 * @author Tobias Weber
 * @date 19-feb-2023, 25-may-2025
 * @license see 'LICENSE' file
 *
 * g++ -std=c++20 -Wall -Wextra -Weffc++ -o gentones gentones.cpp -lboost_system -lboost_program_options
 */

#include <cmath>
#include <numeric>
#include <vector>
#include <unordered_map>
#include <string>
#include <iostream>
#include <fstream>

#include <boost/algorithm/string.hpp>
#include <boost/program_options.hpp>
namespace args = boost::program_options;

#include "tunings.h"


// types
using t_audio = double;
template<class... T> using t_vec = std::vector<T...>;


/**
 * generate an example sequence
 * see: https://en.wikipedia.org/wiki/Symphony_No._9_(Beethoven)#IV._Finale
 */
void generate_example_seq(std::vector<std::size_t>& sequence, std::vector<t_audio>& seconds,
	/*const*/ std::unordered_map<std::string, std::size_t>& tuning_keys)
{
	auto seq1 = [&sequence, &seconds, &tuning_keys](int var = 0)
	{
		if(var == 0)
			sequence.insert(sequence.end(), { tuning_keys["E2"], tuning_keys["F2"], tuning_keys["G2"] });
		else if(var == 1)
			sequence.insert(sequence.end(), { tuning_keys["C2"], tuning_keys["D2"], tuning_keys["E2"] });
		seconds.insert(seconds.end(), { t_audio(0.5), t_audio(0.25), t_audio(0.25) });
	};

	auto seq2 = [&sequence, &seconds, &tuning_keys]()
	{
		sequence.insert(sequence.end(), { tuning_keys["G2"], tuning_keys["F2"], tuning_keys["E2"], tuning_keys["D2"] });
		seconds.insert(seconds.end(), { t_audio(0.25), t_audio(0.25), t_audio(0.25), t_audio(0.25) });
	};

	auto seq3 = [&sequence, &seconds, &tuning_keys](int var = 0)
	{
		if(var == 0)
			sequence.insert(sequence.end(), { tuning_keys["E2"], tuning_keys["D2"], tuning_keys["D2"] });
		else if(var == 1)
			sequence.insert(sequence.end(), { tuning_keys["D2"], tuning_keys["C2"], tuning_keys["C2"] });
		seconds.insert(seconds.end(), { t_audio(0.25 + 0.25/2.), t_audio(0.25/2.), t_audio(0.5) });
	};

	auto seq4 = [&sequence, &seconds, &tuning_keys]()
	{
		sequence.insert(sequence.end(), { tuning_keys["D2"], tuning_keys["E2"], tuning_keys["C2"] });
		seconds.insert(seconds.end(), { t_audio(0.5), t_audio(0.25), t_audio(0.25) });
	};

	auto seq5 = [&sequence, &seconds, &tuning_keys](int var = 0)
	{
		sequence.insert(sequence.end(), { tuning_keys["D2"], tuning_keys["E2"], tuning_keys["F2"], tuning_keys["E2"] });
		seconds.insert(seconds.end(), { t_audio(0.25), t_audio(0.25/2), t_audio(0.25/2), t_audio(0.25) });

		if(var == 0)
			sequence.push_back(tuning_keys["C2"]);
		else if(var == 1)
			sequence.push_back(tuning_keys["D2"]);
		seconds.push_back(0.25);
	};

	auto seq6 = [&sequence, &seconds, &tuning_keys]()
	{
		sequence.insert(sequence.end(), { tuning_keys["C2"], tuning_keys["D2"], tuning_keys["G"], tuning_keys["E2"] });
		seconds.insert(seconds.end(), { t_audio(0.25), t_audio(0.25), t_audio(0.25), t_audio(0.25) });
	};

	auto seq7 = [&sequence, &seconds, &tuning_keys]()
	{
		sequence.insert(sequence.end(), { tuning_keys["E2"], tuning_keys["E2"], tuning_keys["F2"], tuning_keys["G2"] });
		seconds.insert(seconds.end(), { t_audio(0.25), t_audio(0.25), t_audio(0.25), t_audio(0.25) });
	};

	for(int i = 0; i < 2; ++i)
	{
		seq1(0); seq2(); seq1(1); seq3(i);
	}

	seq4(); seq5(0); seq5(1); seq6();
	seq7(); seq2(); seq1(1); seq3(1);
}


int main(int argc, char** argv)
{
	// --------------------------------------------------------------------------------
	// options
	// --------------------------------------------------------------------------------
	bool show_help = false;
	bool all_keys = true;
	bool show_tuning = false;
	bool equal_tuning = true;

	std::size_t num_octaves = 2;
	std::ptrdiff_t shift_half_tones = -2 * 2;

	t_audio base_freq = 261.;
	t_audio base_length = 1.33;
	t_audio time_sig = base_length;  // 4/4

	std::string in_file = "";
	std::string out_file = "";
	std::string out_type = "vhdl";
	int num_freq_bits = 16;
	// --------------------------------------------------------------------------------


	// --------------------------------------------------------------------------------
	// parse command-line arguments
	// --------------------------------------------------------------------------------
	args::options_description arg_descr("tone generator arguments");
	arg_descr.add_options()
		("help,h", args::bool_switch(&show_help),
			("show this help"))
		("base_freq,b", args::value<decltype(base_freq)>(&base_freq),
			("base frequency, default: "
				+ std::to_string(base_freq)).c_str())
		("base_length,l", args::value<decltype(base_length)>(&base_length),
			("base length, default: "
				+ std::to_string(base_length)).c_str())
		("time_sig", args::value<decltype(time_sig)>(&time_sig),
			("time signature, default: "
				+ std::to_string(time_sig)).c_str())
		("octaves,n", args::value<decltype(num_octaves)>(&num_octaves),
			("number of octaves, default: "
				+ std::to_string(num_octaves)).c_str())
		("shift_half_tones,s", args::value<decltype(shift_half_tones)>(&shift_half_tones),
			("number of half-tones to shift, default: "
				+ std::to_string(shift_half_tones)).c_str())
		("equal_tuning,e", args::value<bool>(&equal_tuning),
			("use equal tuning, default: "
				+ std::to_string(equal_tuning)).c_str())
		("output_tuning", args::value<bool>(&show_tuning),
			("output tuning, default: "
				+ std::to_string(show_tuning)).c_str())
		("all_keys", args::value<bool>(&all_keys),
			("generate all keys, default: "
				+ std::to_string(all_keys)).c_str())
		("type,t", args::value<decltype(out_type)>(&out_type),
			("output type (vhdl/text), default: "
				+ out_type).c_str())
		("freq_bits,f", args::value<decltype(num_freq_bits)>(&num_freq_bits),
			("number of bits for frequency, default: "
				+ std::to_string(num_freq_bits)).c_str())
		("input,i", args::value<decltype(in_file)>(&in_file),
			"input data file")
		("output,o", args::value<decltype(out_file)>(&out_file),
			"output rom file");

	args::positional_options_description posarg_descr;
	posarg_descr.add("input", -1);

	auto argparser = args::command_line_parser{argc, argv};
	argparser.style(args::command_line_style::default_style);
	argparser.options(arg_descr);
	argparser.positional(posarg_descr);

	args::variables_map mapArgs;
	auto parsedArgs = argparser.run();
	args::store(parsedArgs, mapArgs);
	args::notify(mapArgs);

	if(show_help)
	{
		std::cerr << arg_descr << std::endl;
		return -1;
	}
	// --------------------------------------------------------------------------------


	// --------------------------------------------------------------------------------
	// generate tuning tones
	// --------------------------------------------------------------------------------
	std::vector<t_audio> tuning;
	if(equal_tuning)
		tuning = get_equal_tuning<t_audio, t_vec>(base_freq, all_keys, num_octaves);
	else
		tuning = get_pythagorean_tuning<t_audio, t_vec>(base_freq, all_keys, num_octaves);
	std::vector<std::string> tuning_names = get_tuning_names<t_vec>(all_keys, num_octaves);


	// map note names to frequency indices
	std::unordered_map<std::string, std::size_t> tuning_keys;
	for(std::size_t i = 0; i < tuning.size(); ++i)
		tuning_keys.insert(std::make_pair(tuning_names[i], i));
	// --------------------------------------------------------------------------------


	// --------------------------------------------------------------------------------
	// generate tone sequence
	// --------------------------------------------------------------------------------
	std::vector<std::size_t> sequence;  // sequence to play
	std::vector<t_audio> seconds;       // lengths of notes

	if(show_tuning)
	{
		// generate sequence from tuning
		shift_half_tones = 0;

		sequence.resize(tuning.size());
		std::iota(sequence.begin(), sequence.end(), 0);

		seconds.resize(tuning.size());
		std::fill(seconds.begin(), seconds.end(), 0.5 / base_length);
	}
	else
	{
		// generate sequence from file or example
		if(in_file != "")
		{
			// read sequence from file
			std::ifstream ifstr(in_file);
			if(!ifstr)
			{
				std::cerr << "Error: Cannot open \"" << in_file << "\"." << std::endl;
				return -1;
			}

			while(ifstr)
			{
				std::string key;
				t_audio secs{};
				ifstr >> key >> secs;
				if(secs <= 0.)
					continue;

				auto iter = tuning_keys.find(key);
				if(iter == tuning_keys.end())
				{
					std::cerr << "Invalid key \"" << key << "\"." << std::endl;
					continue;
				}

				sequence.push_back(iter->second);
				seconds.push_back(secs);
			}
		}
		else
		{
			// use example sequence
			std::cerr << "No input file given, creating an example sequence." << std::endl;
			generate_example_seq(sequence, seconds, tuning_keys);
		}
	}
	// --------------------------------------------------------------------------------


	// --------------------------------------------------------------------------------
	// output
	// --------------------------------------------------------------------------------
	t_audio cur_time_sig = 0.;
	std::size_t cur_seq = 1;

	std::ostream *ostr = &std::cout;
	std::ofstream ofstr;
	if(out_file != "")
	{
		ofstr.open(out_file);
		if(ofstr)
			ostr = &ofstr;
		else
			std::cerr << "Error: Cannot open \"" << out_file << "\"." << std::endl;
	}

	if(out_type == "vhdl")
	{
		(*ostr) << "-- sequence " << cur_seq << std::endl;
		for(std::size_t idx_seq = 0; idx_seq < sequence.size(); ++idx_seq)
		{
			if(cur_time_sig >= time_sig)
			{
				++cur_seq;
				cur_time_sig = 0.;
				(*ostr) << "\n-- sequence " << cur_seq << std::endl;
			}

			std::size_t idx = sequence[idx_seq] + shift_half_tones;
			if(idx >= tuning.size())
			{
				std::cerr << "Error: Invalid tuning index: " << idx << "." << std::endl;
				continue;
			}

			t_audio len = seconds[idx_seq] * base_length;
			t_audio freq = tuning[idx];

			(*ostr) << "(freq => " << num_freq_bits << "d\"" << std::round(freq) << "\""
				<< ", duration => MAIN_HZ / 1000 * " << std::round(len * 1000.)
				<< ", delay => MAIN_HZ / 20)"
				<< ", -- tone " << idx_seq
				<< std::endl;

			cur_time_sig += len;
		}
	}
	else
	{
		(*ostr) << "sequence " << cur_seq << std::endl;
		for(std::size_t idx_seq = 0; idx_seq < sequence.size(); ++idx_seq)
		{
			if(cur_time_sig >= time_sig)
			{
				++cur_seq;
				cur_time_sig = 0.;
				(*ostr) << "\nsequence " << cur_seq << std::endl;
			}

			std::size_t idx = sequence[idx_seq] + shift_half_tones;
			if(idx >= tuning.size())
			{
				std::cerr << "Error: Invalid tuning index: " << idx << "." << std::endl;
				continue;
			}

			t_audio len = seconds[idx_seq] * base_length;
			t_audio freq = tuning[idx];
			const std::string& name = tuning_names[idx];

			(*ostr) << "tone " << idx_seq << ": ";
			(*ostr) << "#" << idx << " = " << name << " = " << freq << " Hz";
			if(idx > 0)
				(*ostr) << " = freq[" << idx-1 << "] * " << freq / tuning[idx-1];
			if(idx > 1)
				(*ostr) << " = freq[0] * " << freq / tuning[0];
			(*ostr) << "; length: " << len << " s";
			(*ostr) << std::endl;

			cur_time_sig += len;
		}
	}
	// --------------------------------------------------------------------------------

	return 0;
}
