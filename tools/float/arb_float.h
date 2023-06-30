/**
 * arbitrary-sized floating points
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 18-May-2023
 * @license see 'LICENSE' file
 *
 * @see https://en.wikipedia.org/wiki/IEEE_754
 */

#ifndef __ARB_FLOAT_H__
#define __ARB_FLOAT_H__


#include <cstdint>
#include <iostream>

#include <boost/multiprecision/integer.hpp>
namespace multiprec = boost::multiprecision;


/**
 * get a native int type of the specified length
 */
template<class t_float> struct native_uint { };

template<> struct native_uint<float> { using type = std::uint32_t; };
template<> struct native_uint<double> { using type = std::uint64_t; };

template<class t_float> using native_uint_t = typename native_uint<t_float>::type;


/**
 * 2^n
 */
template<typename T>
constexpr T int_pow2(T n)
{
	if(n == 0)
		return T(1);
	else if(n > 0)
		return T(1) << static_cast<unsigned>(n);
	else if(n < 0)
		return int_pow2<T>(n + 1) / 2;

	return 0;
}


/**
 * print as binary
 */
template<typename t_int>
void print_bin(std::ostream& ostr, t_int val, t_int len, bool inc_0b = true)
{
	if(inc_0b)
		ostr << "0b";

	for(t_int i=len-1; i>=0; --i)
	{
		if(multiprec::bit_test(val, static_cast<int>(i)))
			ostr << '1';
		else
			ostr << '0';
	}
}


/**
 * print as binary, separating the components
 */
template<typename t_int>
void print_bin_sep(std::ostream& ostr, t_int val, t_int len, t_int exp_len, bool inc_0b = true)
{
	if(inc_0b)
		ostr << "0b";

	for(t_int i=len-1; i>=0; --i)
	{
		if(multiprec::bit_test(val, static_cast<int>(i)))
			ostr << '1';
		else
			ostr << '0';

		if(i == len-1 || i == len-1-exp_len)
			ostr << " | ";
	}
}


/**
 * print as hexadecimal
 */
template<typename t_int>
void print_hex(std::ostream& ostr, t_int val, t_int len, bool inc_0x = true)
{
	if(inc_0x)
		ostr << "0x";

	std::vector<char> chs;
	for(t_int i=0; i<len; i+=4)
	{
		char ch = '0';

		switch(static_cast<std::uint8_t>(val & 0xf))
		{
			case 0: ch = '0'; break;
			case 1: ch = '1'; break;
			case 2: ch = '2'; break;
			case 3: ch = '3'; break;
			case 4: ch = '4'; break;
			case 5: ch = '5'; break;
			case 6: ch = '6'; break;
			case 7: ch = '7'; break;
			case 8: ch = '8'; break;
			case 9: ch = '9'; break;
			case 10: ch = 'a'; break;
			case 11: ch = 'b'; break;
			case 12: ch = 'c'; break;
			case 13: ch = 'd'; break;
			case 14: ch = 'e'; break;
			case 15: ch = 'f'; break;
		}

		chs.push_back(ch);
		val >>= 4;
	}

	for(auto iter=chs.rbegin(); iter!=chs.rend(); ++iter)
		ostr << *iter;
}


/**
 * e.g., 00010100 -> 3
 */
template<class t_int>
t_int count_initial_zeros(t_int value, t_int length)
{
	t_int idx = 0;

	for(; idx < length; ++idx)
	{
		if(value & (t_int{1} << static_cast<unsigned>(length - idx)))
			break;
	}

	return idx;
}


/**
 * normalise the float's mantissa (including the 1.)
 */
template<class t_int>
void normalise_float(t_int& mant, t_int& expo, t_int mant_len)
{
	while(mant > t_int{1}<<static_cast<unsigned>(mant_len))
	{
		mant >>= 1;
		expo += 1;
	}

	if(mant)
	{
		t_int dist = count_initial_zeros<t_int>(mant, mant_len);
		mant <<= static_cast<unsigned>(dist);
		expo -= static_cast<unsigned>(dist);
	}
}


/**
 * floating point number with arbitrary sizes
 */
template<class _t_int = multiprec::cpp_int>
class ArbFloat
{
public:
	using t_int = _t_int;


public:
	ArbFloat(t_int total_len = 32, t_int exp_len = 8)
		: m_total_len{total_len}, m_exp_len{exp_len}, m_mant_len{total_len-exp_len-1}
	{
		m_exp_bias = int_pow2<t_int>(m_exp_len - 1) - 1;

		// bit masks
		m_sign_mask = t_int{1} << static_cast<unsigned>(m_total_len - 1);
		m_exp_mask = m_mant_mask = 0;
		for(t_int idx=m_mant_len; idx<m_total_len-1; ++idx)
			multiprec::bit_set(m_exp_mask, static_cast<unsigned>(idx));
		for(t_int idx=0; idx<m_mant_len; ++idx)
			multiprec::bit_set(m_mant_mask, static_cast<unsigned>(idx));
	}


	/**
	 * copying
	 */
	ArbFloat(const ArbFloat<t_int>& flt) = default;
	constexpr ArbFloat<t_int>& operator=(const ArbFloat<t_int>& flt) = default;


	t_int GetTotalLength() const
	{
		return m_total_len;
	}


	t_int GetExponentLength() const
	{
		return m_exp_len;
	}


	t_int GetMantissaLength() const
	{
		return m_mant_len;
	}


	t_int GetExponentBias() const
	{
		return m_exp_bias;
	}


	bool IsZero() const
	{
		return m_value == 0;
	}


	bool IsNegativeZero() const
	{
		return GetSign() && GetExponent(false)==0 && GetMantissa(false)==0;
	}


	/**
	 * conert from another float of possibly different bit sizes
	 */
	void ConvertFrom(const ArbFloat<t_int>& flt)
	{
		if(flt.IsZero())
		{
			m_value = 0;
			return;
		}
		if(flt.IsNegativeZero())
		{
			m_value = 0;
			SetSign(true);
			return;
		}

		auto [old_num, old_denom] = flt.GetMantissaRatio();
		auto [new_num, new_denom] = GetMantissaRatio();

		SetSign(flt.GetSign());
		SetMantissa(/*old_num*/ flt.GetMantissa(false) * new_denom / old_denom);
		SetExponent(flt.GetExponent(true), true);
		m_mant_shift = 0;
	}


	/**
	 * set the bits from a string with 0/1 values
	 */
	void SetBinary(const std::string& bin)
	{
		unsigned bit_idx = 0;

		for(char ch : bin)
		{
			if(ch == '0')
			{
				multiprec::bit_unset(m_value,
					static_cast<unsigned>(m_total_len) - bit_idx - 1);

				++bit_idx;
			}
			else if(ch == '1')
			{
				multiprec::bit_set(m_value,
					static_cast<unsigned>(m_total_len) - bit_idx - 1);

				++bit_idx;
			}

			// string larger than total bit size?
			if(bit_idx >= static_cast<unsigned>(m_total_len))
				break;
		}
	}


	/**
	 * set the bits from a string with 0-f values
	 */
	void SetHex(const std::string& hex)
	{
		m_value = 0;
		unsigned bit_pos = 0;

		for(auto iter=hex.rbegin(); iter!=hex.rend(); ++iter)
		{
			char ch = *iter;
			t_int val = 0;

			switch(ch)
			{
				case '0': val = 0; break;
				case '1': val = 1; break;
				case '2': val = 2; break;
				case '3': val = 3; break;
				case '4': val = 4; break;
				case '5': val = 5; break;
				case '6': val = 6; break;
				case '7': val = 7; break;
				case '8': val = 8; break;
				case '9': val = 9; break;
				case 'a': case 'A': val = 0xa; break;
				case 'b': case 'B': val = 0xb; break;
				case 'c': case 'C': val = 0xc; break;
				case 'd': case 'D': val = 0xd; break;
				case 'e': case 'E': val = 0xe; break;
				case 'f': case 'F': val = 0xf; break;
			}

			m_value |= val << bit_pos;
			bit_pos += 4;
		}
	}


	/**
	 * set the bits from the corresponding native float type
	 */
	template<class t_float = float>
	void InterpretFrom(t_float f)
	{
		using t_native_uint = native_uint_t<t_float>;
		m_value = *reinterpret_cast<t_native_uint*>(&f);
	}


	/**
	 * interpret the value as a native float type
	 */
	template<class t_float = float>
	t_float InterpretAs() const
	{
		using t_native_uint = native_uint_t<t_float>;
		t_native_uint val = static_cast<t_native_uint>(m_value);
		return *reinterpret_cast<t_float*>(&val);
	}


	/**
	 * get the value of the mantissa (including or excluding the 1.)
	 */
	t_int GetMantissa(bool inc_one = true) const
	{
		t_int mant = m_value & m_mant_mask;
		if(inc_one)
			mant |= int_pow2<t_int>(m_mant_len + m_mant_shift);
		return mant;
	}


	/**
	 * set the value of the mantissa
	 */
	void SetMantissa(t_int val)
	{
		for(t_int idx=0; idx<m_mant_len; ++idx)
		{
			bool bit = multiprec::bit_test(val, static_cast<unsigned>(idx));
			if(bit)
				multiprec::bit_set(m_value, static_cast<unsigned>(idx));
			else
				multiprec::bit_unset(m_value, static_cast<unsigned>(idx));
		}
	}


	/**
	 * calculate the fraction that the mantissa represents
	 */
	std::pair<t_int, t_int> GetMantissaRatio() const
	{
		t_int num = GetMantissa(true);
		t_int denom = int_pow2<t_int>(m_mant_len);

		return std::make_pair(num, denom);
	}


	/**
	 * get the value of the exponent
	 */
	t_int GetExponent(bool bias = true) const
	{
		t_int exp = (m_value & m_exp_mask) >> static_cast<unsigned>(m_mant_len);
		if(bias)
			exp -= m_exp_bias;
		return exp;
	}


	/**
	 * set the value of the exponent
	 */
	void SetExponent(t_int val, bool needs_bias = true)
	{
		if(needs_bias)
			val += m_exp_bias;

		for(t_int idx=m_mant_len; idx<m_total_len-1; ++idx)
		{
			bool bit = multiprec::bit_test(val, static_cast<unsigned>(idx-m_mant_len));
			if(bit)
				multiprec::bit_set(m_value, static_cast<unsigned>(idx));
			else
				multiprec::bit_unset(m_value, static_cast<unsigned>(idx));
		}
	}


	/**
	 * get the sign of the mantissa: 1: negativ, 0: positive
	 */
	bool GetSign() const
	{
		return (m_value & m_sign_mask) != 0;
	}


	/**
	 * set the sign of the mantissa: 1: negativ, 0: positive
	 */
	void SetSign(bool sign)
	{
		if(sign)
			multiprec::bit_set(m_value, static_cast<unsigned>(m_total_len - 1));
		else
			multiprec::bit_unset(m_value, static_cast<unsigned>(m_total_len - 1));
	}


	/**
	 * increment the exponent, keeping the full floating point value
	 */
	void IncExp(t_int val = 1)
	{
		t_int expo = GetExponent(false);
		t_int mant = GetMantissa(false);

		if(val >= 0)
		{
			expo += val;
			mant >>= static_cast<unsigned>(val);
			m_mant_shift -= val;
		}
		else
		{
			expo += val;
			mant <<= static_cast<unsigned>(-val);
			m_mant_shift -= val;
		}

		SetExponent(expo, false);
		SetMantissa(mant);
	}


	/**
	 * normalise the mantissa
	 */
	void Normalise()
	{
		IncExp(m_mant_shift);
	}


	/**
	 * multiply with another float
	 */
	void Mult(const ArbFloat<t_int>& flt)
	{
		t_int mant_a = GetMantissa(true);
		t_int mant_b = flt.GetMantissa(true);
		t_int mant_c = (mant_a * mant_b) >> static_cast<unsigned>(m_mant_len);

		t_int exp_c = GetExponent(true) + flt.GetExponent(true);

		normalise_float<t_int>(mant_c, exp_c, m_mant_len);

		SetSign(GetSign() ^ flt.GetSign());
		SetMantissa(mant_c);
		SetExponent(exp_c, true);
	}


	/**
	 * divide by another float
	 */
	void Div(const ArbFloat<t_int>& flt)
	{
		t_int mant_a = GetMantissa(true);
		t_int mant_b = flt.GetMantissa(true);

		t_int exp_a = GetExponent(true);
		t_int exp_b = flt.GetExponent(true);

		// shift the dividend to not lose significant digits
		mant_a <<= static_cast<unsigned>(m_mant_len);
		exp_a -= m_mant_len;

		t_int mant_c = (mant_a / mant_b) << static_cast<unsigned>(m_mant_len);
		t_int exp_c = exp_a - exp_b;

		normalise_float<t_int>(mant_c, exp_c, m_mant_len);

		SetSign(GetSign() ^ flt.GetSign());
		SetMantissa(mant_c);
		SetExponent(exp_c, true);
	}


	/**
	 * add another float
	 */
	void Add(const ArbFloat<t_int>& flt)
	{
		t_int mant_a = GetMantissa(true);
		t_int mant_b = flt.GetMantissa(true);

		t_int exp_a = GetExponent(true);
		t_int exp_b = flt.GetExponent(true);

		// find a common exponent
		if(exp_a > exp_b)
		{
			mant_b >>= static_cast<unsigned>(exp_a - exp_b);
			exp_b = exp_a;
		}
		else if(exp_b > exp_a)
		{
			mant_a >>= static_cast<unsigned>(exp_b - exp_a);
			exp_a = exp_b;
		}

		// set signs
		if(GetSign())
			mant_a = -mant_a;
		if(flt.GetSign())
			mant_b = -mant_b;

		// add mantissas
		t_int exp_c = exp_a;
		t_int mant_c = mant_a + mant_b;

		// get sign
		bool sign_c = false;
		if(mant_c < 0)
		{
			sign_c = true;
			mant_c = -mant_c;
		}

		normalise_float<t_int>(mant_c, exp_c, m_mant_len);

		SetSign(sign_c);
		SetMantissa(mant_c);
		SetExponent(exp_c, true);
	}


	/**
	 * get the float's bits
	 */
	t_int GetRawValue() const
	{
		return m_value;
	}


	/**
	 * print an expression representing the float's value
	 */
	std::string PrintExpression(
		bool explicit_num = false, bool explicit_denom = false,
		bool explicit_exp = false) const
	{
		std::ostringstream ostr;
		if(GetSign())
			ostr << "-";

		// mantissa
		auto [num, denom] = GetMantissaRatio();
		if(explicit_num)
			ostr << num;
		else
			ostr << "(" << GetMantissa(false) << " + 2^"
				<< m_mant_len + m_mant_shift << ")";

		ostr << " / ";

		if(explicit_denom)
			ostr << denom;
		else
			ostr << "2^" << m_mant_len;

		// exponent
		ostr << " * 2^";
		if(explicit_exp)
		{
			t_int expo = GetExponent(true);
			if(expo < 0)
				ostr << "(" << expo << ")";
			else
				ostr << expo;
		}
		else
		{
			ostr << "(" << GetExponent(false) << " - " << m_exp_bias << ")";
		}
		return ostr.str();
	}


	/**
	 * print a binary representation of the float
	 */
	std::string PrintBinary(bool separate = false, bool inc_0b = true) const
	{
		auto [num, denom] = GetMantissaRatio();
		t_int expo = GetExponent(true);

		std::ostringstream ostr;
		if(separate)
			print_bin_sep<t_int>(ostr, m_value, m_total_len, m_exp_len, inc_0b);
		else
			print_bin<t_int>(ostr, m_value, m_total_len, inc_0b);
		return ostr.str();
	}


	/**
	 * print a hexadecimal representation of the float
	 */
	std::string PrintHex(bool inc_0x = true) const
	{
		std::ostringstream ostr;
		print_hex<t_int>(ostr, m_value, m_total_len, inc_0x);
		return ostr.str();
	}


	void PrintInfos(std::ostream& ostr = std::cout) const
	{
		ostr << "raw mantissa:  " << GetMantissa(false) << "\n";
		ostr << "raw exponent:  " << GetExponent(false) << "\n";
		ostr << "raw value:     " << m_value << "\n";
		ostr << "raw value:     " << PrintBinary();

		auto [num, denom] = GetMantissaRatio();
		t_int expo = GetExponent(true);
		ostr << "\nexponent:      " << expo << "\n";
		ostr << "mantissa:      " << num << " / " << denom << "\n";
		ostr << "sign:          " << (GetSign() ? "1" : "0") << "\n";
		ostr << "value:         ";
		ostr << PrintExpression() << "\n\n";

		ostr << "\ntotal size:    " << m_total_len << " bits\n";
		ostr << "mantissa size: " << m_mant_len << " bits\n";
		ostr << "exponent size: " << m_exp_len << " bits\n";
		ostr << "exponent bias: " << m_exp_bias << "\n";

		ostr << "\nmantissa mask: ";
		print_bin<t_int>(ostr, m_mant_mask, m_total_len);

		ostr << "\nexponent mask: ";
		print_bin<t_int>(ostr, m_exp_mask, m_total_len);

		ostr << "\nsign mask:     ";
		print_bin<t_int>(ostr, m_sign_mask, m_total_len);

		ostr << "\n";
	}


private:
	// bit sizes and bias
	t_int m_total_len{}, m_exp_len{}, m_mant_len{};
	t_int m_exp_bias{};

	// value the mantissa has been shifted from the normalised value
	t_int m_mant_shift{};

	// bit masks
	t_int m_sign_mask{}, m_exp_mask{}, m_mant_mask{};

	// floating point bitfield
	t_int m_value{};
};


#endif
