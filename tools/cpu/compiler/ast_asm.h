/**
 * ast asm generator
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 14-jun-2022
 * @license see 'LICENSE' file
 */

#ifndef __LR1_AST_ASM_H__
#define __LR1_AST_ASM_H__

#include <unordered_map>
#include <unordered_set>
#include <tuple>
#include <iostream>
#include <cstdint>

#include "lval.h"
#include "ast.h"
#include "symbol.h"
#include "vm/opcodes.h"


class ASTAsm : public ASTMutableVisitor
{
public:
	ASTAsm(std::ostream& ostr = std::cout,
		std::unordered_map<std::size_t, std::tuple<std::string, OpCode>> *ops = nullptr);

	ASTAsm(const ASTAsm&) = delete;
	const ASTAsm& operator=(const ASTAsm&) = delete;

	virtual void visit(ASTToken<t_lval>* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTToken<t_real>* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTToken<t_int>* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTToken<t_str>* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTToken<void*>* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTUnary* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTBinary* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTList* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTCondition* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTLoop* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTFunc* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTFuncCall* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTJump* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTTypedIdent* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTAddrOf* ast, std::size_t level, bool gen_code) override;
	virtual void visit(ASTDeref* ast, std::size_t level, bool gen_code) override;

	void SetStream(std::ostream* ostr) { m_ostr = ostr; }

	void PatchFunctionAddresses();
	void FinishCodegen();

	const SymTab& GetSymbolTable() const { return m_symtab; }


private:
	std::ostream* m_ostr{&std::cout};
	const std::unordered_map<std::size_t, std::tuple<std::string, OpCode>> *m_ops{nullptr};

	ConstTab m_consttab{};                 // table of constants
	SymTab m_symtab{};                     // table of symbols

	t_int m_glob_stack{};                  // current offset into global variable stack
	std::unordered_map<std::string, t_int> m_local_stack{};

	std::string m_cur_func{};              // currently active function
	VMType m_cur_rettype{VMType::UNKNOWN}; // return type of currently active function
	std::vector<std::string> m_cur_loop{}; // currently active loops in function

	// stream positions where addresses need to be patched in
	std::vector<std::tuple<std::string, std::streampos, t_int, const ::ASTBase*>>
		m_func_comefroms{};
	std::vector<std::streampos> m_endfunc_comefroms{};
	std::unordered_multimap<std::string, std::streampos> m_loop_begin_comefroms{};
	std::unordered_multimap<std::string, std::streampos> m_loop_end_comefroms{};
	std::vector<std::tuple<std::streampos, std::streampos>> m_const_addrs{};

	std::size_t m_glob_label{0};           // jump label counter
};


#endif
