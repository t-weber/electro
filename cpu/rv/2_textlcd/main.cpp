/**
 * writes a message to the lcd
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date 14-sep-2025
 * @license see 'LICENSE' file
 */

#include "string.h"
#include "textlcd.h"


/**
 * example calculation
 */
template<typename t_int>
t_int fac(t_int i) noexcept
{
	if(i == 0 || i == 1)
		return 1;
	return i * fac<t_int>(i - 1);
}


extern "C" int main() noexcept
{
	txtlcd::clear<char>();

	for(unsigned int i = 0; i < TXTLCD_ROWS; ++i)
	{
		unsigned int val = i + 5;
		unsigned int res = fac(val);

		txtlcd::print<char>(i, 0, val, "! = ", res);
	}

	txtlcd::update<char>();
	return 0;
}


#if USE_INTERRUPTS != 0
/**
 * main function for interrupt service routines
 */
extern "C" void isr_main(unsigned int irqs) noexcept
{
	if(irqs & (1 << 3))
	{
		// button pressed
	}
}
#endif
