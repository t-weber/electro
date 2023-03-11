/**
 * asm generator and vm opcodes
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 14-jun-2022
 * @license see 'LICENSE' file
 */

#ifndef __LR1_OPCODES_H__
#define __LR1_OPCODES_H__

#include "types.h"


enum class OpCode : t_byte
{
	HALT     = 0x00,  // stop program
	NOP      = 0x01,  // no operation
	INVALID  = 0x02,  // invalid opcode

	// conversions
	FTOI     = 0x0a,  // cast real to int
	ITOF     = 0x0b,  // cast int to real

	// memory operations
	PUSH     = 0x10,  // push direct integer data
	PUSH_R   = 0x11,  // push direct real data
	WRMEM    = 0x1a,  // write memory
	RDMEM    = 0x1b,  // read memory

	// arithmetic integer operations
	USUB     = 0x20,  // unary -
	ADD      = 0x21,  // +
	SUB      = 0x22,  // -
	MUL      = 0x23,  // *
	DIV      = 0x24,  // /
	MOD      = 0x25,  // %
	POW      = 0x26,  // ^

	// integer comparisons
	GT       = 0x2a,  // >
	LT       = 0x2b,  // <
	GEQU     = 0x2c,  // >=
	LEQU     = 0x2d,  // <=
	EQU      = 0x2e,  // ==
	NEQU     = 0x2f,  // !=

	// arithmetic real operations
	USUB_R   = 0x30,  // unary -
	ADD_R    = 0x31,  // +
	SUB_R    = 0x32,  // -
	MUL_R    = 0x33,  // *
	DIV_R    = 0x34,  // /
	MOD_R    = 0x35,  // %
	POW_R    = 0x36,  // ^

	// real comparisons
	GT_R     = 0x3a,  // >
	LT_R     = 0x3b,  // <
	GEQU_R   = 0x3c,  // >=
	LEQU_R   = 0x3d,  // <=
	EQU_R    = 0x3e,  // ==
	NEQU_R   = 0x3f,  // !=

	// logical operations
	AND      = 0x40,  // &&
	OR       = 0x41,  // ||
	XOR      = 0x42,  // ^
	NOT      = 0x43,  // !

	// binary operations
	BINAND   = 0x50,  // &
	BINOR    = 0x51,  // |
	BINXOR   = 0x52,  // ^
	BINNOT   = 0x53,  // ~
	SHL      = 0x54,  // <<
	SHR      = 0x55,  // >>
	ROTL     = 0x56,  // rotate left
	ROTR     = 0x57,  // rotate right

	// jumps and function calls
	JMP      = 0x60,  // unconditional jump to direct address
	JMPCND   = 0x61,  // conditional jump to direct address
	CALL     = 0x6a,  // call function
	RET      = 0x6b,  // return from function
	ICALL    = 0x6c,  // call software interrupt
};


/**
 * get the corresponding opcode for real numbers
 */
[[maybe_unused]]
static OpCode convert_vm_opcode_int_to_real(OpCode op)
{
	t_byte op_num = static_cast<t_byte>(op);
	t_byte op_beg = static_cast<t_byte>(OpCode::USUB);
	t_byte op_end = static_cast<t_byte>(OpCode::NEQU);

	if(op_num >= op_beg && op_num <= op_end)
		return static_cast<OpCode>(op_num | 0x10);

	return op;
}


/**
 * get a string representation of an opcode
 */
template<class t_str = const char*>
constexpr t_str get_vm_opcode_name(OpCode op)
{
	switch(op)
	{
		case OpCode::HALT:      return "halt";
		case OpCode::NOP:       return "nop";
		case OpCode::INVALID:   return "invalid";

		case OpCode::FTOI:      return "ftoi";
		case OpCode::ITOF:      return "itof";

		case OpCode::PUSH:      return "push";
		case OpCode::PUSH_R:    return "push_r";
		case OpCode::WRMEM:     return "wrmem";
		case OpCode::RDMEM:     return "rdmem";

		case OpCode::USUB:      return "usub";
		case OpCode::ADD:       return "add";
		case OpCode::SUB:       return "sub";
		case OpCode::MUL:       return "mul";
		case OpCode::DIV:       return "div";
		case OpCode::MOD:       return "mod";
		case OpCode::POW:       return "pow";

		case OpCode::GT:        return "gt";
		case OpCode::LT:        return "lt";
		case OpCode::GEQU:      return "gequ";
		case OpCode::LEQU:      return "lequ";
		case OpCode::EQU:       return "equ";
		case OpCode::NEQU:      return "nequ";

		case OpCode::USUB_R:    return "usub_r";
		case OpCode::ADD_R:     return "add_r";
		case OpCode::SUB_R:     return "sub_r";
		case OpCode::MUL_R:     return "mul_r";
		case OpCode::DIV_R:     return "div_r";
		case OpCode::MOD_R:     return "mod_r";
		case OpCode::POW_R:     return "pow_r";

		case OpCode::GT_R:      return "gt_r";
		case OpCode::LT_R:      return "lt_r";
		case OpCode::GEQU_R:    return "gequ_r";
		case OpCode::LEQU_R:    return "lequ_r";
		case OpCode::EQU_R:     return "equ_r";
		case OpCode::NEQU_R:    return "nequ_r";

		case OpCode::AND:       return "and";
		case OpCode::OR:        return "or";
		case OpCode::XOR:       return "xor";
		case OpCode::NOT:       return "not";

		case OpCode::BINAND:    return "binand";
		case OpCode::BINOR:     return "binor";
		case OpCode::BINXOR:    return "binxor";
		case OpCode::BINNOT:    return "binnot";
		case OpCode::SHL:       return "shl";
		case OpCode::SHR:       return "shr";
		case OpCode::ROTL:      return "rotl";
		case OpCode::ROTR:      return "rotr";

		case OpCode::JMP:       return "jmp";
		case OpCode::JMPCND:    return "jmpcnd";
		case OpCode::CALL:      return "call";
		case OpCode::RET:       return "ret";
		case OpCode::ICALL:     return "icall";

		default:                return "<unknown>";
	}
}

#endif
