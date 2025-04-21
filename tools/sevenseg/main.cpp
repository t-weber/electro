/**
 * seven segment constants
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 21-April-2025
 * @license see 'LICENSE' file
 */

//
// pins (noninv. & inv.):
//
//  666     000
// 1   5   5   1
// 1   5   5   1
//  000     666
// 2   4   4   2
// 2   4   4   2
//  333     333
//

#include <string>
#include <iostream>
#include <cstdint>


template<class t_bits>
t_bits bitswap(t_bits bits, t_bits NUM)
{
	t_bits new_bits = 0;

	for(t_bits num = 0; num < NUM; ++num)
	{
		if(bits & (1 << num))
			new_bits |= (1 << (NUM - num - 1));
	}

	return new_bits;
}


template<class t_bits>
t_bits bitrot_noninv(t_bits bits)
{
	t_bits new_bits = 0;

	if(bits & (1 << 0))
		new_bits |= (1 << 0);
	if(bits & (1 << 1))
		new_bits |= (1 << 4);
	if(bits & (1 << 2))
		new_bits |= (1 << 5);
	if(bits & (1 << 3))
		new_bits |= (1 << 6);
	if(bits & (1 << 4))
		new_bits |= (1 << 1);
	if(bits & (1 << 5))
		new_bits |= (1 << 2);
	if(bits & (1 << 6))
		new_bits |= (1 << 3);

	return new_bits;
}


template<class t_bits>
t_bits bitrot_inv(t_bits bits)
{
	t_bits new_bits = 0;

	if(bits & (1 << 0))
		new_bits |= (1 << 3);
	if(bits & (1 << 1))
		new_bits |= (1 << 4);
	if(bits & (1 << 2))
		new_bits |= (1 << 5);
	if(bits & (1 << 3))
		new_bits |= (1 << 0);
	if(bits & (1 << 4))
		new_bits |= (1 << 1);
	if(bits & (1 << 5))
		new_bits |= (1 << 2);
	if(bits & (1 << 6))
		new_bits |= (1 << 6);

	return new_bits;
}


template<class t_bits>
void print_vals(t_bits val_inv)
{
	t_bits val_noninv = bitswap<t_bits>(val_inv, 7);
	t_bits val_noninv_rot = bitrot_noninv<t_bits>(val_noninv);
	t_bits val_inv_rot = bitrot_inv<t_bits>(val_inv);

	std::cout << std::hex << "Non-inverted:          0x" << val_noninv << "." << std::endl;
	std::cout << std::hex << "Inverted:              0x" << val_inv << "." << std::endl;
	std::cout << std::hex << "Non-inverted, rotated: 0x" << val_noninv_rot << "." << std::endl;
	std::cout << std::hex << "Inverted, rotated:     0x" << val_inv_rot << "." << std::endl;
}


int main(int argc, char** argv)
{
	using t_bits = std::uint16_t;
	t_bits val_inv = 0;

	/*std::cout << "Enter segment bits in inverted ordering: ";
	for(t_bits num = 0; num < 7; ++num)
	{
		t_bits bitval = 0;
		std::cin >> bitval;
		if(bitval)
			val_inv |= (1 << num);
	}

	print_vals<t_bits>(val_inv);
	*/


	std::vector<t_bits> vals
	{{
		// non-inverted numbering, see: https://en.wikipedia.org/wiki/Seven-segment_display
		0x3f, 0x06, 0x5b, 0x4f, // 0-3
		0x66, 0x6d, 0x7d, 0x07, // 4-7
		0x7f, 0x6f, 0x77, 0x7c, // 8-b
		0x39, 0x5e, 0x79, 0x71  // c-f
	}};

	for(t_bits val : vals)
	{
		print_vals<t_bits>(val);
		std::cout << std::endl;
	}

	return 0;
}
