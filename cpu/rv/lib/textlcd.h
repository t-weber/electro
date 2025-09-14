/**
 * output to a text lcd
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date 14-september-2025
 * @license see 'LICENSE' file
 */

#ifndef __TXT_LCD_H__
#define __TXT_LCD_H__


#include "string.h"


#define TXTLCD_ROWS 4
#define TXTLCD_COLS 20
#define TXTLCD_ADDR 0x3f00  // base address for the text lcd screen buffer
#define TXTLCD_CTRL 0x3eff  // address of the lcd control register 


extern const volatile void* _mem_base;


namespace txtlcd {


template<typename t_char = char>
void print_char(unsigned int row, unsigned int col, t_char c) noexcept
{
	if(row >= TXTLCD_ROWS || col >= TXTLCD_COLS)
		return;

	unsigned long mem_base = reinterpret_cast<unsigned long>(&_mem_base);
	volatile t_char* buf = reinterpret_cast<volatile t_char*>(mem_base + TXTLCD_ADDR);
	buf[row * TXTLCD_COLS + col] = c;
}


template<typename t_char = char>
void clear()
{
	for(unsigned int row = 0; row < TXTLCD_ROWS; ++row)
		for(unsigned int col = 0; col < TXTLCD_COLS; ++col)
			print_char<t_char>(row, col, ' ');
}


template<typename t_char = char>
void update()
{
	unsigned long mem_base = reinterpret_cast<unsigned long>(&_mem_base);
	volatile t_char* buf = reinterpret_cast<volatile t_char*>(mem_base + TXTLCD_CTRL);
	*buf = 1;
}


template<typename t_char = char>
unsigned int print(unsigned int row, unsigned int col, const t_char* c) noexcept
{
	unsigned int cur_col = col;
	while(*c)
	{
		print_char<t_char>(row, cur_col, *c);
		++cur_col;
		++c;
	}

	return cur_col - col;
}


template<typename t_char = char>
unsigned int print(unsigned int row, unsigned int col, t_char* c) noexcept
{
	return print<t_char>(row, col, const_cast<const t_char*>(c));
}


template<typename t_char>
unsigned int print(unsigned int row, unsigned int col, unsigned int i) noexcept
{
	char buf[16];
	str::uint_to_str<t_char, unsigned int>(i, buf, 10);
	return print<t_char>(row, col, buf);
}


template<typename t_char>
unsigned int print(unsigned int row, unsigned int col, int i) noexcept
{
	char buf[16];
	str::int_to_str<t_char, int>(i, buf, 10);
	return print<t_char>(row, col, buf);
}


template<typename t_char>
unsigned int print(unsigned int row, unsigned int col, const void* p) noexcept
{
	unsigned long l = reinterpret_cast<unsigned long>(p);

	char buf[sizeof(l)/8 + 1];
	str::int_to_str<t_char, unsigned long>(l, buf, 16);
	return print<t_char>(row, col, buf);
}


template<typename t_char = char>
unsigned int print(unsigned int row, unsigned int col, void* c) noexcept
{
	return print<t_char>(row, col, const_cast<const void*>(c));
}


template<typename t_char, typename t_arg, typename ...t_args>
void print(unsigned int row, unsigned int col, t_arg&& arg, t_args&& ...args) noexcept
{
	unsigned int deltacol = print<t_char>(row, col, arg);
	print<t_char>(row, col + deltacol, args...);
}


} // namespace txtlcd

#endif
