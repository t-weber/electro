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

#include <vector>
#include <string>
#include <iostream>
#include <iomanip>
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
std::tuple<t_bits, t_bits, t_bits> calc_vals(t_bits val_inv)
{
	t_bits val_noninv = bitswap<t_bits>(val_inv, 7);
	t_bits val_noninv_rot = bitrot_noninv<t_bits>(val_noninv);
	t_bits val_inv_rot = bitrot_inv<t_bits>(val_inv);

	//std::cout << std::hex << "Non-inverted:          0x" << val_noninv << "." << std::endl;
	//std::cout << std::hex << "Inverted:              0x" << val_inv << "." << std::endl;
	//std::cout << std::hex << "Non-inverted, rotated: 0x" << val_noninv_rot << "." << std::endl;
	//std::cout << std::hex << "Inverted, rotated:     0x" << val_inv_rot << "." << std::endl;

	return std::make_tuple(val_noninv, val_noninv_rot, val_inv_rot);
}


enum class Lang
{
	CPP,
	VHDL,
	SV,
};


template<class t_bits>
void print_vals(const std::string& descr, const std::vector<t_bits>& vals, Lang lang = Lang::CPP)
{
	std::ostream& ostr = std::cout;

	const char* prefix = "0x";
	const char* suffix = "";
	const char* comment = "// ";

	if(lang == Lang::VHDL)
	{
		prefix = "7'h";
		suffix = "";
		comment = "-- ";
	}
	else if(lang == Lang::SV)
	{
		prefix = "x\"";
		suffix = "\"";
		comment = "// ";
	}

	ostr << comment << descr << std::endl;

	for(std::size_t idx = 0; idx < vals.size(); ++idx)
	{
		t_bits val = vals[idx];

		ostr << prefix
			<< std::setw(2) << std::setfill('0')
			<< std::hex << val
			<< suffix;

		if(idx < vals.size() - 1)
			ostr << ", ";

		if(((idx + 1) % 4) == 0)
		{
			if(idx == vals.size() - 1)
				ostr << "  ";
			ostr << " " << comment << (idx - 3) << " - " << idx;
			ostr << '\n';
		}
	}

	ostr << std::endl;
}


int main(int argc, char** argv)
{
	Lang lang = Lang::CPP;

	if(argc > 1)
	{
		if(*argv[1] == 'c')
			lang = Lang::CPP;
		else if(*argv[1] == 'v')
			lang = Lang::VHDL;
		else if(*argv[1] == 's')
			lang = Lang::SV;
	}

	using t_bits = std::uint16_t;

	std::vector<t_bits> vals_inv
	{{
		// non-inverted numbering, see: https://en.wikipedia.org/wiki/Seven-segment_display
		0x3f, 0x06, 0x5b, 0x4f, // 0-3
		0x66, 0x6d, 0x7d, 0x07, // 4-7
		0x7f, 0x6f, 0x77, 0x7c, // 8-b
		0x39, 0x5e, 0x79, 0x71  // c-f
	}};

	std::vector<t_bits> vals_noninv, vals_noninv_rot, vals_inv_rot;
	vals_noninv.reserve(vals_inv.size());
	vals_noninv_rot.reserve(vals_inv.size());
	vals_inv_rot.reserve(vals_inv.size());

	for(t_bits val : vals_inv)
	{
		auto [val_noninv, val_noninv_rot, val_inv_rot]
			= calc_vals<t_bits>(val);

		vals_noninv.push_back(val_noninv);
		vals_noninv_rot.push_back(val_noninv_rot);
		vals_inv_rot.push_back(val_inv_rot);
	}

	print_vals("non-inverted numbering", vals_noninv, lang);
	print_vals("inverted numbering", vals_inv, lang);
	print_vals("non-inverted numbering, rotated", vals_noninv_rot, lang);
	print_vals("inverted numbering, rotated", vals_inv_rot, lang);

	return 0;
}
