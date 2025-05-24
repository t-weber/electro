/**
 * generate tones
 * @author Tobias Weber
 * @date 19-feb-2023, 25-may-2025
 * @license see 'LICENSE' file
 *
 * g++ -std=c++20 -Wall -Wextra -Weffc++ -o gentones gentones.cpp
 */

#include <cmath>
#include <numeric>
#include <vector>
#include <unordered_map>
#include <string>
#include <iostream>

#include "tunings.h"


// types
using t_audio = double;
template<class... T> using t_vec = std::vector<T...>;


int main()
{
	// options
	bool all_keys = true;
	bool show_tuning = false;
	bool equal_tuning = true;

	std::size_t num_octaves = 2;
	std::size_t shift_half_tones = -2 * 2;

	t_audio base_freq = 261.;
	t_audio base_length = 1.33;
	t_audio time_sig = base_length;  // 4/4

	bool show_vhdl = true;
	int num_freq_bits = 16;


	// tuning tones
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

	std::vector<std::size_t> sequence;  // sequence to play
	std::vector<t_audio> seconds;       // lengths of notes

	if(show_tuning)
	{
		sequence.resize(tuning.size());
		std::iota(sequence.begin(), sequence.end(), 0);

		seconds.resize(tuning.size());
		std::fill(seconds.begin(), seconds.end(), 0.5 / base_length);
	}
	else
	{
		// https://en.wikipedia.org/wiki/Symphony_No._9_(Beethoven)#IV._Finale
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

	t_audio cur_time_sig = 0.;
	std::size_t cur_seq = 1;

	if(show_vhdl)
	{
		std::cout << "-- sequence " << cur_seq << std::endl;
		for(std::size_t idx_seq = 0; idx_seq < sequence.size(); ++idx_seq)
		{
			if(cur_time_sig >= time_sig)
			{
				++cur_seq;
				cur_time_sig = 0.;
				std::cout << "\n-- sequence " << cur_seq << std::endl;
			}

			std::size_t idx = sequence[idx_seq] + shift_half_tones;
			t_audio len = seconds[idx_seq] * base_length;
			t_audio freq = tuning[idx];

			std::cout << "(freq => " << num_freq_bits << "d\"" << std::round(freq) << "\""
				<< ", duration => MAIN_HZ / 1000 * " << std::round(len * 1000.)
				<< ", delay => MAIN_HZ / 20)"
				<< ", -- tone " << idx_seq
				<< std::endl;

			cur_time_sig += len;
		}
	}
	else
	{
		std::cout << "sequence " << cur_seq << std::endl;
		for(std::size_t idx_seq = 0; idx_seq < sequence.size(); ++idx_seq)
		{
			if(cur_time_sig >= time_sig)
			{
				++cur_seq;
				cur_time_sig = 0.;
				std::cout << "\nsequence " << cur_seq << std::endl;
			}

			std::size_t idx = sequence[idx_seq] + shift_half_tones;
			t_audio len = seconds[idx_seq] * base_length;
			t_audio freq = tuning[idx];
			const std::string& name = tuning_names[idx];

			std::cout << "tone " << idx_seq << ": ";
			std::cout << "#" << idx << " = " << name << " = " << freq << " Hz";
			if(idx > 0)
				std::cout << " = freq[" << idx-1 << "] * " << freq / tuning[idx-1];
			if(idx > 1)
				std::cout << " = freq[0] * " << freq / tuning[0];
			std::cout << "; length: " << len << " s";
			std::cout << std::endl;

			cur_time_sig += len;
		}
	}

	return 0;
}
