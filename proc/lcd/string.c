/**
 * simple libc string replacement functions
 * @author Tobias Weber
 * @date mar-21
 * @license see 'LICENSE' file
 */

#include "string.h"


void reverse_str(t_char* buf, t_size len)
{
	for(t_size i=0; i<len/2; ++i)
	{
		t_size j = len-i-1;

		t_char c = buf[i];
		buf[i] = buf[j];
		buf[j] = c;
	}
}


t_char digit_to_char(uint8_t num, t_size base)
{
	t_size mod = num % base;

	if(mod <= 9)
		return (t_char)mod + '0';
	else
		return (t_char)(mod-10) + 'a';
}


void uint_to_str(uint32_t num, uint32_t base, t_char* buf)
{
	t_size idx = 0;
	while(1)
	{
		uint32_t mod = num % base;
		num /= base;

		if(num==0 && mod==0)
		{
			if(idx == 0)
				buf[idx++] = '0';
			break;
		}

		if(mod <= 9)
			buf[idx] = (t_char)mod + '0';
		else
			buf[idx] = (t_char)(mod-10) + 'a';
		++idx;
	}

	buf[idx] = 0;

	reverse_str(buf, idx);
}


void int_to_str(int32_t num, int32_t base, t_char* buf)
{
	t_size idx = 0;
	t_size beg = 0;

	if(num < 0)
	{
		buf[idx] = '-';
		num = -num;

		++idx;
		++beg;
	}

	while(1)
	{
		int32_t mod = num % base;
		num /= base;

		if(num==0 && mod==0)
		{
			if(idx == 0)
				buf[idx++] = '0';

			break;
		}

		if(mod <= 9)
			buf[idx] = (t_char)mod + '0';
		else
			buf[idx] = (t_char)(mod-10) + 'a';
		++idx;
	}

	buf[idx] = 0;

	reverse_str(buf+beg, idx-beg);
}


void real_to_str(float num, uint32_t base, t_char* buf, uint8_t decimals)
{
	const float eps = 1e-8;

	// negative number?
	t_size idx = 0;
	if(num < 0)
	{
		buf[idx++] = '-';
		num = -num;
	}

	// get number before decimal point
	uint_to_str((uint32_t)num, base, buf+idx);

	// get number after decimal point
	t_char buf_decimals[64];
	for(uint8_t dec=0; dec<decimals; ++dec)
	{
		// strip away digits before decimal point
		num -= (uint32_t)num;

		// get next decimal
		num *= base;
		// for numeric stability
		if(num >= base - eps)
			num = 0;

		uint8_t digit = (uint8_t)num;
		// for numeric stability
		if(num >= (float)digit + 1 - eps)
			++digit;

		buf_decimals[dec] = digit_to_char(digit, base);
	}
	buf_decimals[decimals] = 0;

	// strip away trailing '0's
	for(int16_t dec=decimals-1; dec>=0; --dec)
	{
		if(buf_decimals[dec] == '0')
			buf_decimals[dec] = 0;
		else
			break;
	}

	if(my_strlen(buf_decimals))
	{
		strncat_char(buf, '.', 64);
		my_strncat(buf, buf_decimals, 64);
	}
}


t_size my_strlen(const t_char *str)
{
	t_size len = 0;

	while(str[len])
		++len;

	return len;
}


void my_memset(t_char* mem, t_char val, t_size size)
{
	for(t_size i=0; i<size; ++i)
		mem[i] = val;
}


void my_memset_interleaved(t_char* mem, t_char val, t_size size, uint8_t interleave)
{
	for(t_size i=0; i<size; i+=interleave)
		mem[i] = val;
}


void my_memcpy(t_char* mem_dst, t_char* mem_src, t_size size)
{
	for(t_size i=0; i<size; ++i)
		mem_dst[i] = mem_src[i];
}


void my_memcpy_interleaved(t_char* mem_dst, t_char* mem_src, t_size size, uint8_t interleave)
{
	for(t_size i=0; i<size; i+=interleave)
		mem_dst[i] = mem_src[i];
}


void my_strncpy(t_char* str_dst, const t_char* str_src, t_size max_len)
{
	for(t_size i=0; i<max_len; ++i)
	{
		t_char c = str_src[i];
		str_dst[i] = c;

		if(c == 0)
			break;
	}
}


void my_strncat(t_char* str_dst, const t_char* str_src, t_size max_len)
{
	t_size len = my_strlen(str_dst);
	my_strncpy(str_dst + len, str_src, max_len - len);
}


void strncat_char(t_char* str, t_char c, t_size max_len)
{
	t_size len = my_strlen(str);
	if(len+1 < max_len)
	{
		str[len] = c;
		str[len+1] = 0;
	}
}


int8_t my_strncmp(const t_char* str1, const t_char* str2, t_size max_len)
{
	for(t_size i=0; i<max_len; ++i)
	{
		t_char c1 = str1[i];
		t_char c2 = str2[i];

		if(c1 == c2 && c1 != 0)
			continue;
		else if(c1 < c2)
			return -1;
		else if(c1 > c2)
			return 1;
		else if(c1 == 0 && c2 == 0)
			return 0;
	}

	return 0;
}


int8_t my_strcmp(const t_char* str1, const t_char* str2)
{
	t_size len1 = my_strlen(str1);
	t_size len2 = my_strlen(str2);

	return my_strncmp(str1, str2, my_max(len1, len2));
}


int32_t my_max(int32_t a, int32_t b)
{
	if(b > a)
		return b;
	return a;
}


int8_t my_isupperalpha(t_char c)
{
	return (c>='A' && c<='Z');
}


int8_t my_isloweralpha(t_char c)
{
	return (c>='a' && c<='z');
}


int8_t my_isalpha(t_char c)
{
	return my_isupperalpha(c) || my_isloweralpha(c);
}


int8_t my_isdigit(t_char c, int8_t hex)
{
	int8_t is_num = (c>='0' && c<='9');
	if(hex)
	{
		is_num = is_num &&
			((c>='a' && c<='f') || (c>='A' && c<='F'));
	}

	return is_num;
}


int32_t my_atoi(const t_char* str, int32_t base)
{
	t_size len = my_strlen(str);
	int32_t num = 0;

	for(t_size i=0; i<len; ++i)
	{
		int32_t digit = 0;
		if(my_isdigit(str[i], 0))
			digit = str[i] - '0';
		else if(my_isupperalpha(str[i]))
			digit = (str[i] - 'A') + 10;
		else if(my_isloweralpha(str[i]))
			digit = (str[i] - 'a') + 10;

		num = num*base + digit;
	}

	return num;
}


float my_atof(const t_char* str, int32_t base)
{
	t_size len = my_strlen(str);
	float num = 0, decimal = 0;
	int8_t in_num = 1;
	int32_t denom_pos = 1;

	for(t_size i=0; i<len; ++i)
	{
		if(str[i] == '.')
		{
			in_num = 0;
			continue;
		}

		float digit = 0;
		if(my_isdigit(str[i], 0))
			digit = str[i] - '0';
		else if(my_isupperalpha(str[i]))
			digit = (str[i] - 'A') + 10;
		else if(my_isloweralpha(str[i]))
			digit = (str[i] - 'a') + 10;

		// before decimal point
		if(in_num)
		{
			num = num*((float)base) + digit;
		}

		// after decimal point
		else
		{
			for(int32_t j=0; j<denom_pos; ++j)
				digit /= (float)base;
			decimal += digit;

			++denom_pos;
		}
	}

	return num + decimal;
}


// test
/*#include <stdio.h>
int main()
{
	t_char buf[64];
	real_to_str(-987.01020300, 10, buf, 10);
	puts(buf);
}*/
