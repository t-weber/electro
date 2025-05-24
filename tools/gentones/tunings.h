/**
 * generates tuning frequencies
 * @author Tobias Weber
 * @date 19-feb-2023
 * @license see 'LICENSE' file
 */

#ifndef __TUNINGS_H__
#define __TUNINGS_H__


#include <cmath>
#include <vector>
#include <algorithm>
#include <string>



/**
 * pythagorean tuning
 * generates the sequence C-[C#]-D-[D#]-E-F-[F#]-G-[G#]-A-[A#]-B-C
 * @see https://en.wikipedia.org/wiki/Pythagorean_tuning
 */
template<class t_real = double, template<class...> class t_vec = std::vector>
t_vec<t_real> get_pythagorean_tuning(t_real base_freq, bool all_keys = false, std::size_t octaves = 1)
{
	// octave
	const t_real order2_freq = t_real(2) * base_freq;

	t_vec<t_real> tuning;
	tuning.push_back(base_freq);

	// up from base frequency
	t_real freq = base_freq;
	for(int i = 0; i < 5; ++i)
	{
		freq *= t_real(3)/t_real(2);
		if(freq > order2_freq)
			freq *= t_real(0.5);

		tuning.push_back(freq);
	}

	// down from second order
	freq = order2_freq;
	for(int i = 0; i < (all_keys ? 6 : 1); ++i)
	{
		freq *= t_real(2)/t_real(3);
		if(freq < base_freq)
			freq *= t_real(2);

		tuning.push_back(freq);
	}

	// higher octaves
	std::size_t first_octave_end = tuning.size();
	for(std::size_t i = 1; i < octaves; ++i)
	{
		for(std::size_t j = 0; j < first_octave_end; ++j)
			tuning.push_back(tuning[j] * t_real(i+1));
	}

	// last note from next octave
	tuning.push_back(base_freq * std::pow(t_real(2), t_real(octaves)));

	std::sort(tuning.begin(), tuning.end());
	return tuning;
}



/**
 * equal tuning
 * generates the sequence C-[C#]-D-[D#]-E-F-[F#]-G-[G#]-A-[A#]-B-C
 * @see https://en.wikipedia.org/wiki/Equal_temperament
 * @see https://en.wikipedia.org/wiki/Piano_key_frequencies
 */
template<class t_real = double, template<class...> class t_vec = std::vector>
t_vec<t_real> get_equal_tuning(t_real base_freq, bool all_keys = false, std::size_t octaves = 1)
{
	// halftone step
	const t_real step = std::pow(t_real(2), 1./12.);

	t_vec<t_real> tuning;
	tuning.push_back(base_freq);

	t_real freq = base_freq;
	for(int i = 0; i < 11; ++i)
	{
		freq *= step;

		// skip black piano keys?
		if(!all_keys && (i==0 || i==2 || i==5 || i==7 || i==9))
			continue;

		tuning.push_back(freq);
	}

	// higher octaves
	std::size_t first_octave_end = tuning.size();
	for(std::size_t i = 1; i < octaves; ++i)
	{
		for(std::size_t j = 0; j < first_octave_end; ++j)
			tuning.push_back(tuning[j] * t_real(i+1));
	}

	// last note from next octave
	tuning.push_back(base_freq * std::pow(t_real(2), t_real(octaves)));

	return tuning;
}



template<template<class...> class t_vec = std::vector>
t_vec<std::string> get_tuning_names(bool all_keys = false, std::size_t octaves = 1)
{
	t_vec<std::string> tuning;

	tuning.push_back("C");
	if(all_keys)
		tuning.push_back("C#");
	tuning.push_back("D");
	if(all_keys)
		tuning.push_back("D#");
	tuning.push_back("E");
	tuning.push_back("F");
	if(all_keys)
		tuning.push_back("F#");
	tuning.push_back("G");
	if(all_keys)
		tuning.push_back("G#");
	tuning.push_back("A");
	if(all_keys)
		tuning.push_back("A#");
	tuning.push_back("B");

	// higher octaves
	std::size_t first_octave_end = tuning.size();
	for(std::size_t i = 1; i < octaves; ++i)
	{
		for(std::size_t j = 0; j < first_octave_end; ++j)
			tuning.push_back(tuning[j] + std::to_string(i+1));
	}

	// last note from next octave
	tuning.push_back("C" + std::to_string(octaves+1));

	return tuning;
}


#endif
