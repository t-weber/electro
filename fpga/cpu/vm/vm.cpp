/**
 * zero-address code vm
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 8-jun-2022
 * @license see 'LICENSE' file
 */

#include "vm.h"


VM::VM(t_int memsize, std::optional<t_int> framesize, std::optional<t_int> heapsize)
	: m_memsize{memsize},
	  m_framesize{framesize ? *framesize : memsize/16},
	  m_heapsize{heapsize ? *heapsize : memsize/16}
{
	m_mem.reset(new t_byte[m_memsize]);
	Reset();
}


VM::~VM()
{
	StopTimer();
}


void VM::StartTimer()
{
	if(!m_timer_running)
	{
		m_timer_running = true;
		m_timer_thread = std::thread(&VM::TimerFunc, this);
	}
}


void VM::StopTimer()
{
	m_timer_running = false;
	if(m_timer_thread.joinable())
		m_timer_thread.join();
}


/**
 * function for timer thread
 */
void VM::TimerFunc()
{
	while(m_timer_running)
	{
		std::this_thread::sleep_for(m_timer_ticks);
		RequestInterrupt(m_timer_interrupt);
	}
}


/**
 * signals an interrupt
 */
void VM::RequestInterrupt(t_int num)
{
	m_irqs[num] = true;
}


/**
 * sets the address of an interrupt service routine
 */
void VM::SetISR(t_int num, t_int addr)
{
	m_isrs[num] = addr;

	if(m_debug)
		std::cout << "Set isr " << num << " to address " << addr << "." << std::endl;
}


bool VM::Run()
{
	bool running = true;

	while(running)
	{
		CheckPointerBounds();
		if(m_drawmemimages)
			DrawMemoryImage();

		OpCode op{OpCode::INVALID};
		bool irq_active = false;

		// tests for interrupt requests
		for(t_int irq=0; irq<m_num_interrupts; ++irq)
		{
			if(!m_irqs[irq])
				continue;

			m_irqs[irq] = false;
			if(!m_isrs[irq])
				continue;

			irq_active = true;

			// call interrupt service routine
			PushAddress(*m_isrs[irq], ADDR_FLAG_MEM);
			op = OpCode::CALL;

			// TODO: add specialised ICALL and IRET instructions
			// in case of additional registers that might need saving
			break;
		}

		if(!irq_active)
		{
			t_byte _op = m_mem[m_ip++];
			op = static_cast<OpCode>(_op);
		}

		if(m_debug)
		{
			std::cout << "*** read instruction at ip = " << t_int(m_ip)
				<< ", sp = " << t_int(m_sp)
				<< ", bp = " << t_int(m_bp)
				<< ", gbp = " << t_int(m_gbp)
				<< ", opcode: " << std::hex
				<< static_cast<std::size_t>(op)
				<< " (" << get_vm_opcode_name(op) << ")"
				<< std::dec << ". ***" << std::endl;
		}

		// runtime statistics
		++m_num_ops_run;

		if(m_debug)
		{
			if(auto iter = m_ops_run.find(op); iter != m_ops_run.end())
				++iter->second;
			else
				m_ops_run.emplace(std::make_pair(op, 1));
		}

		// run instruction
		switch(op)
		{
			case OpCode::HALT:
			{
				running = false;
				break;
			}

			case OpCode::NOP:
			{
				break;
			}

			case OpCode::FTOI: // converts t_real value to t_int
			{
				t_real data = PopRaw<t_real>();
				t_int conv = t_int(data);
				if(m_debug)
					std::cout << "converted " << data << " to " << conv << "." << std::endl;

				PushRaw<t_int>(conv);
				break;
			}

			case OpCode::ITOF: // converts t_int value to t_real
			{
				t_int data = PopRaw<t_int>();
				t_real conv = t_real(data);
				if(m_debug)
					std::cout << "converted " << data << " to " << conv << "." << std::endl;

				PushRaw<t_real>(conv);
				break;
			}

			// push direct integer data onto stack
			case OpCode::PUSH:
			{
				t_int val = ReadMemRaw<t_int>(m_ip);
				m_ip += sizeof(t_int);
				PushRaw<t_int>(val);
				break;
			}

			// push direct real data onto stack
			case OpCode::PUSH_R:
			{
				t_real val = ReadMemRaw<t_real>(m_ip);
				m_ip += sizeof(t_real);
				PushRaw<t_real>(val);
				break;
			}

			case OpCode::WRMEM:
			{
				// variable address
				t_int addr = PopAddress();

				// pop data and write it to memory
				t_int val = PopRaw<t_int>();
				WriteMemRaw<t_int>(addr, val);
				break;
			}

			case OpCode::WRMEM_R:
			{
				// variable address
				t_int addr = PopAddress();

				// pop data and write it to memory
				t_real val = PopRaw<t_real>();
				WriteMemRaw<t_real>(addr, val);
				break;
			}

			case OpCode::RDMEM:
			{
				// variable address
				t_int addr = PopAddress();

				// read and push data from memory
				t_int val = ReadMemRaw<t_int>(addr);
				PushRaw<t_int>(val);
				break;
			}

			case OpCode::RDMEM_R:
			{
				// variable address
				t_int addr = PopAddress();

				// read and push data from memory
				t_real val = ReadMemRaw<t_real>(addr);
				PushRaw<t_real>(val);
				break;
			}

			// ----------------------------------------------------
			// integer operations
			// ----------------------------------------------------
			case OpCode::USUB:
			{
				t_int val = PopRaw<t_int>();
				PushRaw<t_int>(-val);
				break;
			}

			case OpCode::ADD:
			{
				OpArithmetic<t_int, '+'>();
				break;
			}

			case OpCode::SUB:
			{
				OpArithmetic<t_int, '-'>();
				break;
			}

			case OpCode::MUL:
			{
				OpArithmetic<t_int, '*'>();
				break;
			}

			case OpCode::DIV:
			{
				OpArithmetic<t_int, '/'>();
				break;
			}

			case OpCode::MOD:
			{
				OpArithmetic<t_int, '%'>();
				break;
			}

			case OpCode::POW:
			{
				OpArithmetic<t_int, '^'>();
				break;
			}

			case OpCode::GT:
			{
				OpComparison<t_int, OpCode::GT>();
				break;
			}

			case OpCode::LT:
			{
				OpComparison<t_int, OpCode::LT>();
				break;
			}

			case OpCode::GEQU:
			{
				OpComparison<t_int, OpCode::GEQU>();
				break;
			}

			case OpCode::LEQU:
			{
				OpComparison<t_int, OpCode::LEQU>();
				break;
			}

			case OpCode::EQU:
			{
				OpComparison<t_int, OpCode::EQU>();
				break;
			}

			case OpCode::NEQU:
			{
				OpComparison<t_int, OpCode::NEQU>();
				break;
			}
			// ----------------------------------------------------

			// ----------------------------------------------------
			// real operations
			// ----------------------------------------------------
			case OpCode::USUB_R:
			{
				t_real val = PopRaw<t_real>();
				PushRaw<t_real>(-val);
				break;
			}

			case OpCode::ADD_R:
			{
				OpArithmetic<t_real, '+'>();
				break;
			}

			case OpCode::SUB_R:
			{
				OpArithmetic<t_real, '-'>();
				break;
			}

			case OpCode::MUL_R:
			{
				OpArithmetic<t_real, '*'>();
				break;
			}

			case OpCode::DIV_R:
			{
				OpArithmetic<t_real, '/'>();
				break;
			}

			case OpCode::MOD_R:
			{
				OpArithmetic<t_real, '%'>();
				break;
			}

			case OpCode::POW_R:
			{
				OpArithmetic<t_real, '^'>();
				break;
			}

			case OpCode::GT_R:
			{
				OpComparison<t_real, OpCode::GT>();
				break;
			}

			case OpCode::LT_R:
			{
				OpComparison<t_real, OpCode::LT>();
				break;
			}

			case OpCode::GEQU_R:
			{
				OpComparison<t_real, OpCode::GEQU>();
				break;
			}

			case OpCode::LEQU_R:
			{
				OpComparison<t_real, OpCode::LEQU>();
				break;
			}

			case OpCode::EQU_R:
			{
				OpComparison<t_real, OpCode::EQU>();
				break;
			}

			case OpCode::NEQU_R:
			{
				OpComparison<t_real, OpCode::NEQU>();
				break;
			}
			// ----------------------------------------------------

			case OpCode::AND:
			{
				OpLogical<'&'>();
				break;
			}

			case OpCode::OR:
			{
				OpLogical<'|'>();
				break;
			}

			case OpCode::XOR:
			{
				OpLogical<'^'>();
				break;
			}

			case OpCode::NOT:
			{
				t_bool val = PopRaw<t_bool>();
				PushRaw<t_bool>(!val);
				break;
			}

			case OpCode::BINAND:
			{
				OpBinary<'&'>();
				break;
			}

			case OpCode::BINOR:
			{
				OpBinary<'|'>();
				break;
			}

			case OpCode::BINXOR:
			{
				OpBinary<'^'>();
				break;
			}

			case OpCode::BINNOT:
			{
				t_int val = PopRaw<t_int>();
				t_int newval = ~val;
				PushRaw<t_int>(newval);
				break;
			}

			case OpCode::SHL:
			{
				OpBinary<'<'>();
				break;
			}

			case OpCode::SHR:
			{
				OpBinary<'>'>();
				break;
			}

			case OpCode::ROTL:
			{
				OpBinary<'l'>();
				break;
			}

			case OpCode::ROTR:
			{
				OpBinary<'r'>();
				break;
			}

			case OpCode::JMP: // jump to direct address
			{
				// get address from stack and set ip
				m_ip = PopAddress();
				break;
			}

			case OpCode::JMPCND: // conditional jump to direct address
			{
				// get address from stack
				t_int addr = PopAddress();

				// get boolean condition result from stack
				t_bool cond = PopRaw<t_bool>();

				// set instruction pointer
				if(cond)
					m_ip = addr;
				break;
			}

			/**
			 * stack frame for functions:
			 *
			 *  --------------------
			 * |  local var n       |  <-- m_sp
			 *  --------------------      |
			 * |      ...           |     |
			 *  --------------------      |
			 * |  local var 2       |     |  m_framesize
			 *  --------------------      |
			 * |  local var 1       |     |
			 *  --------------------      |
			 * |  old m_bp          |  <-- m_bp (= previous m_sp)
			 *  --------------------
			 * |  old m_ip for ret  |
			 *  --------------------
			 * |  func. arg 1       |
			 *  --------------------
			 * |  func. arg 2       |
			 *  --------------------
			 * |  ...               |
			 *  --------------------
			 * |  func. arg n       |
			 *  --------------------
			 */
			case OpCode::CALL: // function call
			{
				t_int funcaddr = PopAddress();

				// save instruction and base pointer and
				// set up the function's stack frame for local variables
				PushAddress(m_ip, ADDR_FLAG_MEM);
				PushAddress(m_bp, ADDR_FLAG_MEM);

				if(m_debug)
				{
					std::cout << "saved base pointer "
						<< m_bp << "." << std::endl;
				}

				m_bp = m_sp;
				m_sp -= m_framesize;

				// jump to function
				m_ip = funcaddr;

				if(m_debug)
				{
					std::cout << "calling function at address "
						<< funcaddr << "." << std::endl;
				}

				break;
			}

			case OpCode::RET: // return from function
			{
				// get number of function arguments
				t_int num_args = PopRaw<t_int>();
				if(m_debug)
				{
					std::cout << "returning from function with "
						<< num_args << " argument(s)."
						<< std::endl;
				}

				// if there's still a value on the stack, use it as return value
				std::optional<t_int> retval;
				if(m_sp + m_framesize < m_bp)
					retval = PopRaw<t_int>();

				// zero the stack frame
				if(m_zeropoppedvals)
					std::memset(m_mem.get()+m_sp, 0, (m_bp-m_sp)*sizeof(t_byte));

				// remove the function's stack frame
				m_sp = m_bp;

				m_bp = PopAddress();
				m_ip = PopAddress();  // jump back

				if(m_debug)
				{
					std::cout << "restored base pointer "
						<< m_bp << "." << std::endl;
				}

				// remove function arguments from stack
				for(t_int arg=0; arg<num_args; ++arg)
					PopRaw<t_int>();

				if(retval)
					PushRaw<t_int>(*retval);
				break;
			}

			case OpCode::ICALL: // call software interrupt
			{
				CallSoftInt();
				break;
			}

			default:
			{
				std::cerr << "Error: Invalid instruction " << std::hex
					<< static_cast<t_int>(op) << std::dec
					<< std::endl;
				return false;
			}
		}

		// wrap around
		if(m_ip > m_memsize)
			m_ip %= m_memsize;
	}

	return true;
}


/**
 * pop an address from the stack
 * an address consists of the index of an register
 * holding the base address and an offset address
 */
t_int VM::PopAddress()
{
	// get register/type info and address from stack
	t_int _addr = PopRaw<t_int>();
	auto [addr, flags] = decode_addr<t_int>(_addr);

	if(m_debug)
	{
		std::cout << "popped address " << addr
			<< " relative to " << get_vm_base_reg(flags)
			<< "." << std::endl;
	}

	// get absolute address using base address from register
	switch(flags)
	{
		case ADDR_FLAG_MEM: break;
		case ADDR_FLAG_IP: addr += m_ip; break;
		case ADDR_FLAG_BP: addr += m_bp; break;
		case ADDR_FLAG_GBP: addr += m_gbp; break;
		case ADDR_FLAG_HP: addr += m_hp; break;
		//default: throw std::runtime_error("Unknown address base register."); break;
	}

	return addr;
}


/**
 * push an address to stack
 */
void VM::PushAddress(t_int addr, t_int flag)
{
	addr = encode_addr<t_int>(addr, flag);
	PushRaw<t_int>(addr);
}



void VM::Reset()
{
	m_ip = 0;
	m_sp = m_memsize - m_framesize - m_heapsize;
	m_bp = m_memsize - m_heapsize;
	m_bp -= sizeof(t_int) + 1; // padding of max. data type size to avoid writing beyond memory size
	m_gbp = m_bp;
	m_hp = m_memsize - m_heapsize;

	std::memset(m_mem.get(), static_cast<t_byte>(OpCode::HALT), m_memsize*sizeof(t_byte));
	m_code_range[0] = m_code_range[1] = -1;

	m_num_ops_run = 0;
	m_ops_run.clear();
}


/**
 * sets or updates the range of memory where executable code resides
 */
void VM::UpdateCodeRange(t_int begin, t_int end)
{
	if(m_code_range[0] < 0 || m_code_range[1] < 0)
	{
		// set range
		m_code_range[0] = begin;
		m_code_range[1] = end;
	}
	else
	{
		// update range
		m_code_range[0] = std::min(m_code_range[0], begin);
		m_code_range[1] = std::max(m_code_range[1], end);
	}
}


void VM::SetMem(t_int addr, t_byte data)
{
	CheckMemoryBounds(addr, sizeof(t_byte));

	m_mem[addr % m_memsize] = data;
}


void VM::SetMem(t_int addr, const std::string& data, bool is_code)
{
	if(is_code)
		UpdateCodeRange(addr, addr + data.size());

	for(std::size_t i=0; i<data.size(); ++i)
		SetMem(addr + t_int(i), static_cast<t_byte>(data[i]));
}


void VM::SetMem(t_int addr, const t_byte* data, std::size_t size, bool is_code)
{
	if(is_code)
		UpdateCodeRange(addr, addr + size);

	for(std::size_t i=0; i<size; ++i)
		SetMem(addr + t_int(i), data[i]);
}


void VM::CheckMemoryBounds(t_int addr, std::size_t size) const
{
	if(!m_checks)
		return;

	if(std::size_t(addr) + size > std::size_t(m_memsize) || addr < 0)
		throw std::runtime_error("Tried to access out of memory bounds.");
}


void VM::CheckPointerBounds() const
{
	if(!m_checks)
		return;

	// check code range?
	bool chk_c = (m_code_range[0] >= 0 && m_code_range[1] >= 0);

	if(m_ip > m_memsize || m_ip < 0 || (chk_c && (m_ip < m_code_range[0] || m_ip >= m_code_range[1])))
	{
		std::ostringstream msg;
		msg << "Instruction pointer " << t_int(m_ip) << " is out of memory bounds.";
		throw std::runtime_error(msg.str());
	}
	if(m_sp > m_memsize || m_sp < 0 || (chk_c && m_sp >= m_code_range[0] && m_sp < m_code_range[1]))
	{
		std::ostringstream msg;
		msg << "Stack pointer " << t_int(m_sp) << " is out of memory bounds.";
		throw std::runtime_error(msg.str());
	}
	if(m_bp > m_memsize || m_bp < 0 || (chk_c && m_bp >= m_code_range[0] && m_bp < m_code_range[1]))
	{
		std::ostringstream msg;
		msg << "Base pointer " << t_int(m_bp) << " is out of memory bounds.";
		throw std::runtime_error(msg.str());
	}
	if(m_gbp > m_memsize || m_gbp < 0 || (chk_c && m_gbp >= m_code_range[0] && m_gbp < m_code_range[1]))
	{
		std::ostringstream msg;
		msg << "Global base pointer " << t_int(m_gbp) << " is out of memory bounds.";
		throw std::runtime_error(msg.str());
	}
}
