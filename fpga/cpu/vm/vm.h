/**
 * zero-address code vm
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 8-jun-2022
 * @license see 'LICENSE' file
 */

#ifndef __LALR1_0ACVM_H__
#define __LALR1_0ACVM_H__


#include <type_traits>
#include <memory>
#include <array>
#include <optional>
#include <iostream>
#include <sstream>
#include <bit>
#include <thread>
#include <chrono>
#include <atomic>
#include <string>
#include <cstring>
#include <cmath>

#include "opcodes.h"
#include "helpers.h"


class VM
{
public:
	static constexpr const t_int m_num_interrupts = 16;
	static constexpr const t_int m_timer_interrupt = 0;


public:
	VM(t_int memsize = 0x1000, std::optional<t_int> framesize = std::nullopt,
		std::optional<t_int> heapsize = std::nullopt);
	~VM();

	void SetDebug(bool b) { m_debug = b; }
	void SetDrawMemImages(bool b) { m_drawmemimages = b; }
	void SetChecks(bool b) { m_checks = b; }
	void SetZeroPoppedVals(bool b) { m_zeropoppedvals = b; }

	void Reset();
	bool Run();

	void SetMem(t_int addr, t_byte data);
	void SetMem(t_int addr, const t_byte* data, std::size_t size, bool is_code = false);
	void SetMem(t_int addr, const std::string& data, bool is_code = false);

	t_int GetSP() const { return m_sp; }
	t_int GetBP() const { return m_bp; }
	t_int GetGBP() const { return m_gbp; }
	t_int GetIP() const { return m_ip; }

	void SetSP(t_int sp) { m_sp = sp; }
	void SetBP(t_int bp) { m_bp = bp; }
	void SetGBP(t_int gbp) { m_gbp = gbp; }
	void SetIP(t_int ip) { m_ip = ip; }


	/**
	 * signals an interrupt
	 */
	void RequestInterrupt(t_int num);


	/**
	 * visualises vm memory utilisation
	 */
	void DrawMemoryImage();


	/**
	 * get the value on top of the stack
	 */
	template<class t_val, t_int valsize = sizeof(t_val)>
	t_val TopRaw(t_int sp_offs = 0) const
	{
		t_int addr = m_sp + sp_offs;
		CheckMemoryBounds(addr, valsize);

		return *reinterpret_cast<t_val*>(m_mem.get() + addr);
	}


	/**
	 * pop a raw value from the stack
	 */
	template<class t_val, t_int valsize = sizeof(t_val)>
	t_val PopRaw()
	{
		CheckMemoryBounds(m_sp, valsize);

		t_val *valptr = reinterpret_cast<t_val*>(m_mem.get() + m_sp);
		t_val val = *valptr;

		if(m_zeropoppedvals)
			*valptr = 0;

		m_sp += valsize;	// stack grows to lower addresses
		return val;
	}


protected:
	/**
	 * call software interrupt
	 */
	void CallSoftInt();


	/**
	 * pop an address from the stack
	 */
	t_int PopAddress();


	/**
	 * push an address to stack
	 */
	void PushAddress(t_int addr, t_int flag = ADDR_FLAG_MEM);


	/**
	 * read a raw value from memory
	 */
	template<class t_val>
	t_val ReadMemRaw(t_int addr) const
	{
		CheckMemoryBounds(addr, sizeof(t_val));
		t_val val = *reinterpret_cast<t_val*>(&m_mem[addr]);

		return val;
	}


	/**
	 * write a raw value to memory
	 */
	template<class t_val>
	void WriteMemRaw(t_int addr, const t_val& val)
	{
		CheckMemoryBounds(addr, sizeof(t_val));
		*reinterpret_cast<t_val*>(&m_mem[addr]) = val;
	}


	/**
	 * push a raw value onto the stack
	 */
	template<class t_val, t_int valsize = sizeof(t_val)>
	void PushRaw(const t_val& val)
	{
		CheckMemoryBounds(m_sp, valsize);

		m_sp -= valsize;	// stack grows to lower addresses
		*reinterpret_cast<t_val*>(m_mem.get() + m_sp) = val;

		if(m_debug)
		{
			std::cout << "pushed "
				<< get_vm_type_name<t_val, t_str>()
				<< " " << val << "." << std::endl;
		}
	}


	/**
	 * arithmetic operation
	 */
	template<class t_val, char op>
	t_val OpArithmetic(const t_val& val1, const t_val& val2)
	{
		t_val result{};

		if constexpr(op == '+')
			result = val1 + val2;
		else if constexpr(op == '-')
			result = val1 - val2;
		else if constexpr(op == '*')
			result = val1 * val2;
		else if constexpr(op == '/')
			result = val1 / val2;
		else if constexpr(op == '%' && std::is_integral_v<t_val>)
			result = val1 % val2;
		else if constexpr(op == '%' && std::is_floating_point_v<t_val>)
			result = std::fmod(val1, val2);
		else if constexpr(op == '^' && std::is_integral_v<t_val>)
			result = pow<t_val>(val1, val2);
		else if constexpr(op == '^' && std::is_floating_point_v<t_val>)
			result = pow<t_val>(val1, val2);

		return result;
	}


	/**
	 * arithmetic operation
	 */
	template<char op>
	void OpArithmetic()
	{
		t_int val2 = PopRaw<t_int>();
		t_int val1 = PopRaw<t_int>();

		t_int result = OpArithmetic<t_int, op>(val1, val2);
		PushRaw<t_int>(result);
	}


	/**
	 * logical operation
	 */
	template<char op>
	void OpLogical()
	{
		t_bool val2 = PopRaw<t_bool>();
		t_bool val1 = PopRaw<t_bool>();

		t_bool result = 0;

		if constexpr(op == '&')
			result = val1 && val2;
		else if constexpr(op == '|')
			result = val1 || val2;
		else if constexpr(op == '^')
			result = val1 ^ val2;

		PushRaw<t_bool>(result);
	}


	/**
	 * binary operation
	 */
	template<class t_val, char op>
	t_val OpBinary(const t_val& val1, const t_val& val2)
	{
		t_val result{};

		// int operators
		if constexpr(std::is_same_v<std::decay_t<t_int>, t_int>)
		{
			if constexpr(op == '&')
				result = val1 & val2;
			else if constexpr(op == '|')
				result = val1 | val2;
			else if constexpr(op == '^')
				result = val1 ^ val2;
			else if constexpr(op == '<')  // left shift
				result = val1 << val2;
			else if constexpr(op == '>')  // right shift
				result = val1 >> val2;
			else if constexpr(op == 'l')  // left rotation
				result = static_cast<t_int>(std::rotl<t_uint>(val1, static_cast<int>(val2)));
			else if constexpr(op == 'r')  // right rotation
				result = static_cast<t_int>(std::rotr<t_uint>(val1, static_cast<int>(val2)));
		}

		return result;
	}


	/**
	 * binary operation
	 */
	template<char op>
	void OpBinary()
	{
		t_int val2 = PopRaw<t_int>();
		t_int val1 = PopRaw<t_int>();

		t_int result = OpBinary<t_int, op>(val1, val2);
		PushRaw<t_int>(result);
	}


	/**
	 * comparison operation
	 */
	template<class t_val, OpCode op>
	t_bool OpComparison(const t_val& val1, const t_val& val2)
	{
		t_bool result = 0;

		if constexpr(op == OpCode::GT)
			result = (val1 > val2);
		else if constexpr(op == OpCode::LT)
			result = (val1 < val2);
		else if constexpr(op == OpCode::GEQU)
			result = (val1 >= val2);
		else if constexpr(op == OpCode::LEQU)
			result = (val1 <= val2);
		else if constexpr(op == OpCode::EQU)
		{
			if constexpr(std::is_same_v<std::decay_t<t_val>, t_real>)
				result = (std::abs(val1 - val2) <= m_eps);
			else
				result = (val1 == val2);
		}
		else if constexpr(op == OpCode::NEQU)
		{
			if constexpr(std::is_same_v<std::decay_t<t_val>, t_real>)
				result = (std::abs(val1 - val2) > m_eps);
			else
				result = (val1 != val2);
		}

		return result;
	}


	/**
	 * comparison operation
	 */
	template<OpCode op>
	void OpComparison()
	{
		t_int val2 = PopRaw<t_int>();
		t_int val1 = PopRaw<t_int>();
		t_bool result = OpComparison<t_int, op>(val1, val2);
		PushRaw<t_bool>(result);
	}


	/**
	 * sets the address of an interrupt service routine
	 */
	void SetISR(t_int num, t_int addr);

	void StartTimer();
	void StopTimer();


private:
	void CheckMemoryBounds(t_int addr, std::size_t size = 1) const;
	void CheckPointerBounds() const;
	void UpdateCodeRange(t_int begin, t_int end);

	void TimerFunc();


private:
	bool m_debug{false};               // write debug messages
	bool m_checks{true};               // do memory boundary checks
	bool m_drawmemimages{false};       // write memory dump images
	bool m_zeropoppedvals{false};      // zero memory of popped values
	t_real m_eps{std::numeric_limits<t_real>::epsilon()};

	std::unique_ptr<t_byte[]> m_mem{}; // ram
	t_int m_code_range[2]{-1, -1};     // address range where the code resides

	// registers
	t_int m_ip{};                      // instruction pointer
	t_int m_sp{};                      // stack pointer
	t_int m_bp{};                      // base pointer for local variables
	t_int m_gbp{};                     // global base pointer
	t_int m_hp{};                      // heap pointer

	// memory sizes and ranges
	t_int m_memsize = 0x1000;          // total memory size
	t_int m_framesize = 0x100;         // size per function stack frame
	t_int m_heapsize = 0x100;          // heap memory size

	// signals interrupt requests
	std::array<std::atomic_bool, m_num_interrupts> m_irqs{};
	// addresses of the interrupt service routines
	std::array<std::optional<t_int>, m_num_interrupts> m_isrs{};

	std::thread m_timer_thread{};
	bool m_timer_running{false};
	std::chrono::milliseconds m_timer_ticks{250};
};


#endif
