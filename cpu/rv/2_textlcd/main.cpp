/**
 * writes a message to the lcd
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date 14-sep-2025
 * @license see 'LICENSE' file
 */

#include "string.h"


#define LCD_ADDR  0x3f00  // base address for the lcd text


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
	extern const volatile void* _mem_base;
	unsigned long mem_base = reinterpret_cast<unsigned long>(&_mem_base);

	volatile char* buf = reinterpret_cast<volatile char*>(mem_base + LCD_ADDR);
	buf[0] = 'A'; buf[1] = 'B'; buf[2] = 'C'; buf[3] = 'D';
	buf[4] = '1'; buf[5] = '2'; buf[6] = '3'; buf[7] = '4';

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
