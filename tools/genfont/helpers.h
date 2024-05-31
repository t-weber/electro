/**
 * helper functions
 * @author Tobias Weber
 * @date may-2024
 * @license see 'LICENSE' file
 */

#ifndef __GENFONT_HELPERS_H__
#define __GENFONT_HELPERS_H__


#include <vector>


template<class t_bitset>
void reverse_bitset(t_bitset& bitset)
{
	std::size_t N = bitset.size();
	t_bitset bitset_cpy = bitset;

	for(std::size_t i = 0; i < N; ++i)
		bitset[N - i - 1] = bitset_cpy[i];
}



template<class t_bitset>
t_bitset unite_bitsets(const std::vector<t_bitset>& bitsets)
{
	std::size_t N = 0;
	for(const t_bitset& bitset : bitsets)
		N += bitset.size();

	t_bitset bitset_new{N, 0};
	std::size_t cur_idx = 0;

	for(const t_bitset& bitset : bitsets)
	{
		std::size_t M = bitset.size();
		for(std::size_t idx = 0; idx < M; ++idx)
			bitset_new[N - (cur_idx + idx) - 1] = bitset[M - idx - 1];
		cur_idx += M;
	}

	return bitset_new;
}



template<class t_bitset>
bool is_zero(t_bitset& bitset)
{
	for(std::size_t i = 0; i < bitset.size(); ++i)
	{
		if(bitset[i])
			return false;
	}

	return true;
}


#endif
