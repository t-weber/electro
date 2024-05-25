/**
 * asm generator and vm opcodes
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 14-jun-2022
 * @license see 'LICENSE' file
 */

#ifndef __LR1_VM_TYPES_H__
#define __LR1_VM_TYPES_H__

#include <cstdint>
#include <string>
#include "compiler/lval.h"



enum class VMType : t_byte
{
	UNKNOWN     = 0x00,
	REAL        = 0x01,
	INT         = 0x02,
	BOOLEAN     = 0x03,
};


// address flag bits
#define ADDR_FLAG_NONE  0
#define ADDR_FLAG_MEM   (1 << 3*8)  // address refering to absolute memory locations
#define ADDR_FLAG_IP    (2 << 3*8)  // address relative to the instruction pointer
#define ADDR_FLAG_BP    (3 << 3*8)  // address relative to a local base pointer
#define ADDR_FLAG_GBP   (4 << 3*8)  // address relative to the global base pointer
#define ADDR_FLAG_HP    (5 << 3*8)  // address relative to the heap pointer

// address masks
#define ADDR_FLAG_MASK  0x7f000000
#define ADDR_FLAG_SIGN  0x80000000
#define ADDR_MASK       0x80ffffff


template<class t_int = ::t_int>
t_int encode_addr(t_int raw_addr, t_int flags)
{
	// make place for flags
	if(raw_addr < 0)
		raw_addr &= ~ADDR_FLAG_MASK;

	return raw_addr | flags;
}


template<class t_int = ::t_int>
std::pair<t_int, t_int> decode_addr(t_int addr)
{
	t_int flags = addr & ADDR_FLAG_MASK;

	// remove flag bits
	t_int raw_addr = addr & ADDR_MASK;
	if(addr & ADDR_FLAG_SIGN)
		raw_addr |= ADDR_FLAG_MASK;

	return std::make_pair(raw_addr, flags);
}


/**
 * get a string representation of a base register name
 */
template<class t_str = const char*>
constexpr t_str get_vm_base_reg(t_int flag)
{
	switch(flag)
	{
		case ADDR_FLAG_NONE:      return "none";
		case ADDR_FLAG_MEM:       return "absolute";
		case ADDR_FLAG_IP:        return "ip";
		case ADDR_FLAG_BP:        return "bp";
		case ADDR_FLAG_GBP:       return "gbp";
		case ADDR_FLAG_HP:        return "hp";
		default:                  return "<unknown>";
	}
}


constexpr t_int get_vm_type_size(VMType ty)
{
	switch(ty)
	{
		case VMType::UNKNOWN:     return sizeof(t_int);
		case VMType::REAL:        return sizeof(t_real);
		case VMType::INT:         return sizeof(t_int);
		case VMType::BOOLEAN:     return sizeof(t_bool);
		default:                  return sizeof(t_int);
	}
}


template<class t_val, class t_str = const char*>
constexpr t_str get_vm_type_name()
{
	if constexpr(std::is_same_v<t_val, t_int>)
		return "integer";
	else if constexpr(std::is_same_v<t_val, t_real>)
		return "real";
	else if constexpr(std::is_same_v<t_val, t_bool>)
		return "boolean";
	return "unknown";
}


/**
 * get a string representation of a type name
 * (run-time version)
 */
template<class t_str = const char*>
constexpr t_str get_vm_type_name(VMType ty)
{
	switch(ty)
	{
		case VMType::UNKNOWN:     return "unknown";
		case VMType::REAL:        return "real";
		case VMType::INT:         return "integer";
		case VMType::BOOLEAN:     return "boolean";
		default:                  return "<unknown>";
	}
}


/**
 * get derived data type for casting
 */
static inline VMType derive_data_type(VMType ty1, VMType ty2)
{
	if(ty1 == ty2)
		return ty1;
	else if(ty1 == VMType::INT && ty2 == VMType::REAL)
		return VMType::REAL;
	else if(ty1 == VMType::REAL && ty2 == VMType::INT)
		return VMType::REAL;

	return VMType::UNKNOWN;
}


#endif
