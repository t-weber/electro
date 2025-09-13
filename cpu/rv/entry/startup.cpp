/**
 * c++ program startup code
 * @author Tobias Weber (0000-0002-7230-1932)
 * @date 24-aug-2025
 * @license see 'LICENSE' file
 */

//#define DEBUG_STARTUP

#include "string.h"
#ifdef DEBUG_STARTUP
	#include "serial.h"
#endif


// section with uninitialised globals
extern "C" void *_globals_uninit_addr, *_globals_uninit_end;


/**
 * startup code (zeroing uninitialised global variables)
 */
extern "C" void _startup() noexcept
{
	void *addr = reinterpret_cast<void*>(&_globals_uninit_addr);
	void *end = reinterpret_cast<void*>(&_globals_uninit_end);

#ifdef DEBUG_STARTUP
	serial::print<char>("bss range: ", addr, ", ", end, "\n");
	serial::print<char>("bss size: ", (int)((char*)end - (char*)addr), "\n");
#endif

	if(end <= addr)
		return;

	str::my_memset<char>((char*)addr, 0x00,
		reinterpret_cast<char*>(end) - reinterpret_cast<char*>(addr));
}
