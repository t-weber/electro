/**
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date 24-aug-2025
 * @license see 'LICENSE' file
 */

#include "string.h"


#define RESULT_ADDR  0x3f00 // address that is watched in the sv testbench


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

	// inspect in qemu mon, for 64 bit: x /8c 0x80003f00
	volatile char* buf = reinterpret_cast<volatile char*>(mem_base + RESULT_ADDR);
	buf[0] = 'A'; buf[1] = 'B'; buf[2] = 'C'; buf[3] = '\n'; buf[4] = 0;

	for(unsigned int val = 0; val <= 10; ++val)
	{
		unsigned int res = fac<unsigned int>(val);
		// write the result to memory
		*reinterpret_cast<volatile unsigned int*>(mem_base + RESULT_ADDR) = res;
	}


	unsigned int val = 1;
	bool shift_left = true;
	while(true)
	{
		*reinterpret_cast<volatile unsigned int*>(mem_base + RESULT_ADDR) = val;

		if(shift_left)
			val <<= 1;
		else
			val >>= 1;

		if(shift_left && (val & (1 << 7)))
			shift_left = false;
		if(!shift_left && (val & 1))
			shift_left = true;
	}

	return 0;
}


#if USE_INTERRUPTS != 0
/**
 * main function for interrupt service routines
 */
extern "C" void isr_main(unsigned int irqs) noexcept
{
	// flip a bit if the button was pressed
	if(irqs & (1 << 3))
	{
		extern const volatile void* _mem_base;
		unsigned long mem_base = reinterpret_cast<unsigned long>(&_mem_base);
		volatile unsigned long* buf = reinterpret_cast<volatile unsigned long*>(mem_base + RESULT_ADDR + 4);
		buf[0] = ~buf[0];
	}
}
#endif
