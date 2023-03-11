/**
 * zero-address asm code generator
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 14-jun-2022
 * @license see 'LICENSE' file
 */

#include "ast_asm.h"
#include <cmath>


/**
 * exit with an error
 */
static void throw_err(const ::ASTBase* ast, const std::string& err)
{
	if(ast)
	{
		std::ostringstream ostr;

		if(auto line_range = ast->GetLineRange(); line_range)
		{
			auto start_line = std::get<0>(*line_range);
			auto end_line = std::get<1>(*line_range);

			if(start_line == end_line)
				ostr << "Line " << start_line << ": ";
			else
				ostr << "Lines " << start_line << "..." << end_line << ": ";

			ostr << err;
		}

		throw std::runtime_error(ostr.str());
	}
	else
	{
		throw std::runtime_error(err);
	}
}


ASTAsm::ASTAsm(std::ostream& ostr,
	std::unordered_map<std::size_t, std::tuple<std::string, OpCode>> *ops)
	: m_ostr{&ostr}, m_ops{ops}
{
}


void ASTAsm::visit(
	[[maybe_unused]] ASTToken<t_lval>* ast,
	[[maybe_unused]] std::size_t level)
{
	std::cerr << "Error: " << __func__ << " not implemented." << std::endl;
}


void ASTAsm::visit(ASTToken<t_real>* ast, [[maybe_unused]] std::size_t level)
{
	if(!ast->HasLexerValue())
		return;
	t_real val = static_cast<t_real>(ast->GetLexerValue());

	m_ostr->put(static_cast<t_byte>(OpCode::PUSH));
	m_ostr->write(reinterpret_cast<const char*>(&val), sizeof(t_real));
}


void ASTAsm::visit(ASTToken<t_int>* ast, [[maybe_unused]] std::size_t level)
{
	if(!ast->HasLexerValue())
		return;
	t_int val = static_cast<t_int>(ast->GetLexerValue());

	m_ostr->put(static_cast<t_byte>(OpCode::PUSH));
	m_ostr->write(reinterpret_cast<const char*>(&val), sizeof(t_int));
}


void ASTAsm::visit(ASTToken<t_str>* ast, [[maybe_unused]] std::size_t level)
{
	if(!ast->HasLexerValue())
		return;

	const t_str& val = ast->GetLexerValue();

	// the token names a variable identifier
	if(ast->IsIdent())
	{
		t_str varname;

		if(m_cur_func != "")
			varname = m_cur_func + "/" + val;
		else
			varname = val;

		// get variable address and push it
		const SymInfo *sym = m_symtab.GetSymbol(varname);
		// symbol not yet seen -> register it
		if(!sym)
		{
			VMType symty = ast->GetDataType();
			t_int sym_size = get_vm_type_size(symty);

			// in global scope
			if(m_cur_func == "")
			{
				sym = m_symtab.AddSymbol(varname, -m_glob_stack,
					ADDR_FLAG_GBP, symty);
				m_glob_stack += sym_size;
			}

			// in local function scope
			else
			{
				m_local_stack.try_emplace(m_cur_func, 0);
				m_local_stack[m_cur_func] += sym_size;
				sym = m_symtab.AddSymbol(varname, -m_local_stack[m_cur_func],
					ADDR_FLAG_BP, symty);
			}
		}
		else
		{
			if(ast->GetDataType() == VMType::UNKNOWN)
				ast->SetDataType(sym->ty);
		}

		m_ostr->put(static_cast<t_byte>(OpCode::PUSH));
		// relative address
		t_int addr = encode_addr<t_int>(sym->addr, sym->loc);
		m_ostr->write(reinterpret_cast<const char*>(&addr), sizeof(t_int));

		// dereference it, if the variable is on the rhs of an assignment
		if(!ast->IsLValue() && !sym->is_func)
			m_ostr->put(static_cast<t_byte>(OpCode::RDMEM));
	}

	// the token names a string literal
	/*else
	{
		// get string constant address
		std::streampos str_addr = m_consttab.AddConst(val);

		// push string constant address
		m_ostr->put(static_cast<t_byte>(OpCode::PUSH));

		std::streampos addr_pos = m_ostr->tellp();
		str_addr -= addr_pos;
		str_addr -= static_cast<std::streampos>(sizeof(t_int));
		str_addr = encode_addr<t_int>(str_addr, ADDR_FLAG_IP);

		m_const_addrs.push_back(std::make_tuple(addr_pos, str_addr));
		m_ostr->write(reinterpret_cast<const char*>(&str_addr), sizeof(t_int));

		// dereference string constant address
		m_ostr->put(static_cast<t_byte>(OpCode::RDMEM));
	}*/
}


void ASTAsm::visit(
	[[maybe_unused]] ASTToken<void*>* ast,
	[[maybe_unused]] std::size_t level)
{
	std::cerr << "Error: " << __func__ << " not implemented." << std::endl;
}


void ASTAsm::visit(ASTUnary* ast, [[maybe_unused]] std::size_t level)
{
	// run the operand
	ast->GetChild(0)->accept(this, level+1);

	if(ast->GetDataType() == VMType::UNKNOWN)
		ast->DeriveDataType();
	VMType ty = ast->GetDataType();

	std::size_t opid = ast->GetOpId();
	OpCode op = std::get<OpCode>(m_ops->at(opid));

	if(op == OpCode::ADD || op == OpCode::ADD_R)
		op = OpCode::NOP;
	else if(op == OpCode::SUB)
	{
		if(ty == VMType::INT)
			op = OpCode::USUB;
		else if(ty == VMType::REAL)
			op = OpCode::USUB_R;
		else
			throw_err(ast, "Invalid data type in unary expression.");
	}
	else
		throw_err(ast, "Invalid unary expression.");

	m_ostr->put(static_cast<t_byte>(op));
}


void ASTAsm::visit(ASTBinary* ast, [[maybe_unused]] std::size_t level)
{
	// run the operands
	for(std::size_t childidx=0; childidx<2; ++childidx)
	{
		auto child = ast->GetChild(childidx);
		child->accept(this, level+1);
	}

	if(ast->GetDataType() == VMType::UNKNOWN)
		ast->DeriveDataType();

	std::size_t opid = ast->GetOpId();
	VMType ty = ast->GetDataType();

	// iterate the operands
	for(std::size_t childidx=0; childidx<2; ++childidx)
	{
		auto child = ast->GetChild(childidx);
		VMType subty = child->GetDataType();
		if(subty != ty && opid != '=' /* no cast on assignments */)
		{
			// child type is different from derived type -> cast
			if(ty == VMType::INT)
				m_ostr->put(static_cast<t_byte>(OpCode::FTOI));
			else if(ty == VMType::REAL)
				m_ostr->put(static_cast<t_byte>(OpCode::ITOF));
		}
	}

	// generate the binary operation
	OpCode op = std::get<OpCode>(m_ops->at(opid));
	if(op != OpCode::INVALID)	// use opcode directly
	{
		if(ty == VMType::INT)
			m_ostr->put(static_cast<t_byte>(op));
		else if(ty == VMType::REAL)
			m_ostr->put(static_cast<t_byte>(
				convert_vm_opcode_int_to_real(op)));
		else
			throw_err(ast, "Invalid data type in binary expression.");
	}
	else
	{
		// TODO: decide on special cases
	}
}


void ASTAsm::visit(ASTList* ast, [[maybe_unused]] std::size_t level)
{
	for(std::size_t i=0; i<ast->NumChildren(); ++i)
		ast->GetChild(i)->accept(this, level+1);
}


void ASTAsm::visit(ASTCondition* ast, [[maybe_unused]] std::size_t level)
{
	// condition
	ast->GetCondition()->accept(this, level+1);

	t_int skipEndCond = 0;             // how many bytes to skip to jump to end of the if block?
	t_int skipEndIf = 0;               // how many bytes to skip to jump to end of the entire if statement?
	std::streampos skip_addr = 0;      // stream position with the condition jump label
	std::streampos skip_else_addr = 0; // stream position with the if block jump label

	// if the condition is not fulfilled...
	m_ostr->put(static_cast<t_byte>(OpCode::NOT));

	// ...skip to the end of the if block
	m_ostr->put(static_cast<t_byte>(OpCode::PUSH)); // push jump address
	skip_addr = m_ostr->tellp();
	skipEndCond = encode_addr<t_int>(skipEndCond, ADDR_FLAG_IP);
	m_ostr->write(reinterpret_cast<const char*>(&skipEndCond), sizeof(t_int));
	m_ostr->put(static_cast<t_byte>(OpCode::JMPCND));

	// if block
	std::streampos before_if_block = m_ostr->tellp();
	ast->GetIfBlock()->accept(this, level+1);
	if(ast->GetElseBlock())
	{
		// skip to end of if statement if there's an else block
		m_ostr->put(static_cast<t_byte>(OpCode::PUSH)); // push jump address
		skip_else_addr = m_ostr->tellp();
		skipEndIf = encode_addr<t_int>(skipEndIf, ADDR_FLAG_IP);
		m_ostr->write(reinterpret_cast<const char*>(&skipEndIf), sizeof(t_int));
		m_ostr->put(static_cast<t_byte>(OpCode::JMP));
	}
	std::streampos after_if_block = m_ostr->tellp();

	// go back and fill in missing number of bytes to skip
	skipEndCond = after_if_block - before_if_block;
	m_ostr->seekp(skip_addr);
	skipEndCond = encode_addr<t_int>(skipEndCond, ADDR_FLAG_IP);
	m_ostr->write(reinterpret_cast<const char*>(&skipEndCond), sizeof(t_int));
	m_ostr->seekp(after_if_block);

	// else block
	if(ast->GetElseBlock())
	{
		std::streampos before_else_block = m_ostr->tellp();
		ast->GetElseBlock()->accept(this, level+1);
		std::streampos after_else_block = m_ostr->tellp();

		// go back and fill in missing number of bytes to skip
		skipEndIf = after_else_block - before_else_block;
		m_ostr->seekp(skip_else_addr);
		skipEndIf = encode_addr<t_int>(skipEndIf, ADDR_FLAG_IP);
		m_ostr->write(reinterpret_cast<const char*>(&skipEndIf), sizeof(t_int));
		m_ostr->seekp(after_else_block);
	}
}


void ASTAsm::visit(ASTLoop* ast, [[maybe_unused]] std::size_t level)
{
	std::size_t labelLoop = m_glob_label++;

	std::ostringstream ostrLabel;
	ostrLabel << "loop_" << labelLoop;
	m_cur_loop.push_back(ostrLabel.str());

	// run condition
	std::streampos loop_begin = m_ostr->tellp();
	ast->GetCondition()->accept(this, level+1); // condition

	t_int skip = 0;  // how many bytes to skip to jump to end of the block?
	std::streampos skip_addr = 0;

	// if the condition is not fulfilled...
	m_ostr->put(static_cast<t_byte>(OpCode::NOT));

	// ... jump to the end
	m_ostr->put(static_cast<t_byte>(OpCode::PUSH)); // push jump address
	skip_addr = m_ostr->tellp();
	skip = encode_addr<t_int>(skip, ADDR_FLAG_IP);
	m_ostr->write(reinterpret_cast<const char*>(&skip), sizeof(t_int));
	m_ostr->put(static_cast<t_byte>(OpCode::JMPCND));

	// run loop block
	std::streampos before_block = m_ostr->tellp();
	ast->GetBlock()->accept(this, level+1); // block

	// loop back
	m_ostr->put(static_cast<t_byte>(OpCode::PUSH)); // push jump address
	std::streampos after_block = m_ostr->tellp();
	t_int skip_back = loop_begin - after_block;
	skip_back -= sizeof(t_int) + 1;
	skip_back = encode_addr<t_int>(skip_back, ADDR_FLAG_IP);
	m_ostr->write(reinterpret_cast<const char*>(&skip_back), sizeof(t_int));
	m_ostr->put(static_cast<t_byte>(OpCode::JMP));

	// go back and fill in missing number of bytes to skip
	after_block = m_ostr->tellp();
	skip = after_block - before_block;
	skip = encode_addr<t_int>(skip, ADDR_FLAG_IP);
	m_ostr->seekp(skip_addr);
	m_ostr->write(reinterpret_cast<const char*>(&skip), sizeof(t_int));

	// fill in any saved, unset start-of-loop jump addresses (continues)
	while(true)
	{
		auto iter = m_loop_begin_comefroms.find(ostrLabel.str());
		if(iter == m_loop_begin_comefroms.end())
			break;

		std::streampos pos = iter->second;
		m_loop_begin_comefroms.erase(iter);

		t_int to_skip = loop_begin - pos;
		// already skipped over address and jmp instruction
		to_skip -= sizeof(t_int);
		to_skip = encode_addr<t_int>(to_skip, ADDR_FLAG_IP);
		m_ostr->seekp(pos);
		m_ostr->write(reinterpret_cast<const char*>(&to_skip), sizeof(t_int));
	}

	// fill in any saved, unset end-of-loop jump addresses (breaks)
	while(true)
	{
		auto iter = m_loop_end_comefroms.find(ostrLabel.str());
		if(iter == m_loop_end_comefroms.end())
			break;

		std::streampos pos = iter->second;
		m_loop_end_comefroms.erase(iter);

		t_int to_skip = after_block - pos;
		// already skipped over address and jmp instruction
		to_skip -= sizeof(t_int);
		to_skip = encode_addr<t_int>(to_skip, ADDR_FLAG_IP);
		m_ostr->seekp(pos);
		m_ostr->write(reinterpret_cast<const char*>(&to_skip), sizeof(t_int));
	}

	// go to end of stream
	m_ostr->seekp(after_block);

	m_cur_loop.pop_back();
}


void ASTAsm::visit(ASTFunc* ast, [[maybe_unused]] std::size_t level)
{
	if(m_cur_func != "")
		throw_err(ast, "Nested functions are not allowed.");

	// function name
	const std::string& func_name = ast->GetName();
	m_cur_func = func_name;
	m_cur_rettype = ast->GetDataType();

	//std::cout << "entered function " << m_cur_func
	//	<< " having return type " << get_vm_type_name(m_cur_rettype)
	//	<< std::endl;

	// number of function arguments
	t_int num_args = static_cast<t_int>(ast->NumArgs());

	std::streampos jmp_end_streampos;
	t_int end_func_addr = 0;

	// jump to the end of the function to prevent accidental execution
	m_ostr->put(static_cast<t_byte>(OpCode::PUSH)); // push jump address
	jmp_end_streampos = m_ostr->tellp();
	end_func_addr = encode_addr<t_int>(end_func_addr, ADDR_FLAG_IP);
	m_ostr->write(reinterpret_cast<const char*>(&end_func_addr), sizeof(t_int));
	m_ostr->put(static_cast<t_byte>(OpCode::JMP));


	// function arguments
	if(ast->GetArgs())
	{
		for(std::size_t i=0; i<ast->GetArgs()->NumChildren(); ++i)
		{
			auto ident = std::dynamic_pointer_cast<ASTToken<t_str>>(ast->GetArgs()->GetChild(i));
			const t_str& argname = ident->GetLexerValue();
			t_str varname = m_cur_func + "/" + argname;

			VMType argty = ident->GetDataType();
			m_symtab.AddSymbol(varname, (i+2)*get_vm_type_size(argty), ADDR_FLAG_BP, argty);
		}
	}


	std::streampos before_block = m_ostr->tellp();
	//std::cout << "function \"" << func_name << "\" at start address " << before_block << std::endl;

	// add function to symbol table
	m_symtab.AddSymbol(func_name, before_block, ADDR_FLAG_MEM, VMType::UNKNOWN, true, num_args);

	ast->GetBlock()->accept(this, level+1); // block


	std::streampos ret_streampos = m_ostr->tellp();

	// push number of arguments and return
	m_ostr->put(static_cast<t_byte>(OpCode::PUSH));
	m_ostr->write(reinterpret_cast<const char*>(&num_args), sizeof(t_int));
	m_ostr->put(static_cast<t_byte>(OpCode::RET));

	// fill in end-of-function jump address
	std::streampos end_func_streampos = m_ostr->tellp();
	end_func_addr = end_func_streampos - before_block;
	end_func_addr = encode_addr<t_int>(end_func_addr, ADDR_FLAG_IP);
	m_ostr->seekp(jmp_end_streampos);
	m_ostr->write(reinterpret_cast<const char*>(&end_func_addr), sizeof(t_int));

	// fill in any saved, unset end-of-function jump addresses
	for(std::streampos pos : m_endfunc_comefroms)
	{
		t_int to_skip = ret_streampos - pos;
		// already skipped over address and jmp instruction
		to_skip -= sizeof(t_int) + 1;
		to_skip = encode_addr<t_int>(to_skip, ADDR_FLAG_IP);
		m_ostr->seekp(pos);
		m_ostr->write(reinterpret_cast<const char*>(&to_skip), sizeof(t_int));
	}
	m_endfunc_comefroms.clear();
	m_ostr->seekp(end_func_streampos);

	m_cur_func = "";
	m_cur_rettype = VMType::UNKNOWN;
	m_cur_loop.clear();
}


void ASTAsm::visit(ASTFuncCall* ast, [[maybe_unused]] std::size_t level)
{
	const std::string& func_name = ast->GetName();
	t_int num_args = static_cast<t_int>(ast->NumArgs());

	// push the function arguments
	if(ast->GetArgs())
		ast->GetArgs()->accept(this, level+1);

	// call internal function
	// get function address and push it
	const SymInfo *sym = m_symtab.GetSymbol(func_name);
	t_int func_addr = 0;
	if(sym)
	{
		// function address already known
		func_addr = sym->addr;
		//std::cout << "calling function \"" << func_name << "\" at address " << func_addr << std::endl;

		if(num_args != sym->num_args)
		{
			std::ostringstream msg;
			msg << "Function \"" << func_name << "\" takes " << sym->num_args
				<< " arguments, but " << num_args << " were given.";
			throw_err(ast, msg.str());
		}
	}

	// push relative function address
	m_ostr->put(static_cast<t_byte>(OpCode::PUSH));

	// already skipped over address and jmp instruction
	std::streampos addr_pos = m_ostr->tellp();
	t_int to_skip = static_cast<t_int>(func_addr - addr_pos);
	to_skip -= sizeof(t_int) + 1;
	to_skip = encode_addr<t_int>(to_skip, ADDR_FLAG_IP);
	m_ostr->write(reinterpret_cast<const char*>(&to_skip), sizeof(t_int));

	m_ostr->put(static_cast<t_byte>(OpCode::CALL));

	if(!sym)
	{
		// function address not yet known
		m_func_comefroms.emplace_back(
			std::make_tuple(func_name, addr_pos, num_args, ast));
	}
}


void ASTAsm::visit(ASTJump* ast, [[maybe_unused]] std::size_t level)
{
	if(ast->GetJumpType() == ASTJump::JumpType::RETURN)
	{
		VMType expr_type{VMType::UNKNOWN};

		if(ast->GetExpr())
		{
			ast->GetExpr()->accept(this, level+1);
			expr_type = ast->GetExpr()->GetDataType();
		}

		if(m_cur_func == "")
			throw_err(ast, "Tried to return outside any function.");

		//std::cout << "expected return data type: " << get_vm_type_name(m_cur_rettype)
		//	<< ", actual data type: " << get_vm_type_name(expr_type)
		//	<< std::endl;

		if(ast->GetExpr())
		{
			// cast if data types are different
			if(m_cur_rettype == VMType::INT && expr_type == VMType::REAL)
				m_ostr->put(static_cast<t_byte>(OpCode::FTOI));
			else if(m_cur_rettype == VMType::REAL && expr_type == VMType::INT)
				m_ostr->put(static_cast<t_byte>(OpCode::ITOF));
		}

		// jump to the end of the function
		m_ostr->put(static_cast<t_byte>(OpCode::PUSH)); // push jump address
		m_endfunc_comefroms.push_back(m_ostr->tellp());
		t_int dummy_addr = 0;
		dummy_addr = encode_addr<t_int>(dummy_addr, ADDR_FLAG_IP);
		m_ostr->write(reinterpret_cast<const char*>(&dummy_addr), sizeof(t_int));
		m_ostr->put(static_cast<t_byte>(OpCode::JMP));
	}
	else if(ast->GetJumpType() == ASTJump::JumpType::BREAK
		|| ast->GetJumpType() == ASTJump::JumpType::CONTINUE)
	{
		if(!m_cur_loop.size())
			throw_err(ast, "Tried to use break/continue outside loop.");

		t_int loop_depth = 0; // how many loop levels to break/continue?

		if(ast->GetExpr())
		{
			auto int_val = std::dynamic_pointer_cast<ASTToken<t_int>>(ast->GetExpr());
			auto real_val = std::dynamic_pointer_cast<ASTToken<t_real>>(ast->GetExpr());

			if(int_val)
				loop_depth = int_val->GetLexerValue();
			else if(real_val)
				loop_depth = static_cast<t_int>(std::round(real_val->GetLexerValue()));
		}

		// reduce to maximum loop depth
		if(static_cast<std::size_t>(loop_depth) >= m_cur_loop.size() || loop_depth < 0)
			loop_depth = static_cast<t_int>(m_cur_loop.size()-1);

		const std::string& cur_loop = *(m_cur_loop.rbegin() + loop_depth);

		// jump to the beginning (continue) or end (break) of the loop
		m_ostr->put(static_cast<t_byte>(OpCode::PUSH)); // push jump address
		if(ast->GetJumpType() == ASTJump::JumpType::BREAK)
			m_loop_end_comefroms.insert(std::make_pair(cur_loop, m_ostr->tellp()));
		else if(ast->GetJumpType() == ASTJump::JumpType::CONTINUE)
			m_loop_begin_comefroms.insert(std::make_pair(cur_loop, m_ostr->tellp()));
		t_int dummy_addr = 0;
		dummy_addr = encode_addr<t_int>(dummy_addr, ADDR_FLAG_IP);
		m_ostr->write(reinterpret_cast<const char*>(&dummy_addr), sizeof(t_int));
		m_ostr->put(static_cast<t_byte>(OpCode::JMP));
	}
}


void ASTAsm::visit(
	[[maybe_unused]] ASTTypedIdent* ast,
	[[maybe_unused]] std::size_t level)
{
	// should not be present in final ast
	std::cerr << "Error: " << __func__ << " not implemented." << std::endl;
}


/**
 * fill in function addresses for calls
 */
void ASTAsm::PatchFunctionAddresses()
{
	for(const auto& [func_name, pos, num_args, call_ast] : m_func_comefroms)
	{
		const SymInfo *sym = m_symtab.GetSymbol(func_name);
		if(!sym)
		{
			throw_err(call_ast,
				"Tried to call unknown function \"" + func_name + "\".");
		}

		if(num_args != sym->num_args)
		{
			std::ostringstream msg;
			msg << "Function \"" << func_name << "\" takes " << sym->num_args
				<< " arguments, but " << num_args << " were given.";
			throw_err(call_ast, msg.str());
		}

		m_ostr->seekp(pos);

		// write relative function address
		t_int to_skip = sym->addr - pos;
		// already skipped over address and jmp instruction
		to_skip -= sizeof(t_int) + 1;
		m_ostr->write(reinterpret_cast<const char*>(&to_skip), sizeof(t_int));
	}

	// seek to end of stream
	m_ostr->seekp(0, std::ios_base::end);
}


void ASTAsm::FinishCodegen()
{
	// add a final halt instruction
	m_ostr->put(static_cast<t_byte>(OpCode::HALT));

	// write constants block
	std::streampos consttab_pos = m_ostr->tellp();
	if(auto [constsize, constbytes] = m_consttab.GetBytes(); constsize && constbytes)
	{
		m_ostr->write((char*)constbytes.get(), constsize);
	}

	// patch in the addresses of the constants
	for(auto [addr_pos, const_addr] : m_const_addrs)
	{
		t_int addr = const_addr;

		// add address offset to constants table
		addr += consttab_pos;

		// write new address
		m_ostr->seekp(addr_pos);
		m_ostr->write(reinterpret_cast<const char*>(&addr), sizeof(t_int));
	}

	// move stream pointers back to the end
	m_ostr->seekp(0, std::ios_base::end);
}
