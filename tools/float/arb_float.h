/**
 * arbitrary-sized floating points
 * @author Tobias Weber
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


template<typename T>
constexpr T int_pow2(T n)
{
	if(n == 0)
		return 1;
	else if(n == 1)
		return 2;
	else if(n > 1)
		return 2 * int_pow2<T>(n - 1);
	else if(n < 0)
		return int_pow2<T>(n + 1) / 2;

	return 0;
}


template<typename t_int>
void print_bin(std::ostream& ostr, t_int val, t_int len)
{
	ostr << "0b";

	for(t_int i=len-1; i>=0; --i)
	{
		if(multiprec::bit_test(val, static_cast<int>(i)))
			ostr << '1';
		else
			ostr << '0';
	}
}


class ArbFloat
{
public:
	using t_int = multiprec::cpp_int;


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
	 * set the bits from the corresponding native float type
	 */
	template<class t_float = float>
	void InterpretFrom(t_float _f)
	{
		using t_native_uint = native_uint_t<t_float>;
		const t_native_uint f = *reinterpret_cast<t_native_uint*>(&_f);

		m_value = 0;
		for(std::size_t idx=0; idx<sizeof(_f)*8; ++idx)
		{
			if(f & (1 << idx))
				multiprec::bit_set(m_value, idx);
		}
	}


	/**
	 * interpret the value as a native float type
	 */
	template<class t_float>
	t_float InterpretAs() const
	{
		using t_native_uint = native_uint_t<t_float>;

		t_native_uint val = static_cast<t_native_uint>(m_value);
		return *reinterpret_cast<t_float*>(&val);
	}


	/**
	 * get the value of the mantissa
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


	void PrintInfos(std::ostream& ostr = std::cout) const
	{
		ostr << "raw mantissa:  " << GetMantissa(false) << "\n";
		ostr << "raw exponent:  " << GetExponent(false) << "\n";
		ostr << "raw value:     " << m_value << "\n";
		ostr << "raw value:     ";
		print_bin<t_int>(ostr, m_value, m_total_len);

		auto [num, denom] = GetMantissaRatio();
		t_int expo = GetExponent(true);
		ostr << "\nexponent:      " << expo << "\n";
		ostr << "mantissa:      " << num << " / " << denom << "\n";
		ostr << "sign:          " << (GetSign() ? "1" : "0") << "\n";
		ostr << "value:         ";
		if(GetSign())
			ostr << "-";
		ostr << num << " / " << denom << " * 2^" << expo << "\n";

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
