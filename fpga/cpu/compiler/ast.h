/**
 * ast
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 14-jun-2022
 * @license see 'LICENSE' file
 */

#ifndef __LR1_AST_H__
#define __LR1_AST_H__

#include <memory>
#include <vector>
#include <utility>
#include <functional>
#include <limits>
#include <optional>
#include <iostream>
#include <sstream>

#include "lval.h"
#include "lalr1/ast.h"
#include "vm/types.h"


// forward declarations
class ASTBase;
using t_astbaseptr = std::shared_ptr<ASTBase>;

template<class t_lval> class ASTToken;

class ASTUnary;
class ASTBinary;

class ASTList;

class ASTCondition;
class ASTLoop;

class ASTFunc;
class ASTFuncCall;
class ASTJump;

class ASTTypedIdent;

class ASTAddrOf;
class ASTDeref;


enum class ASTType
{
	TOKEN,

	UNARY,
	BINARY,
	LIST,

	CONDITION,
	LOOP,

	JUMP,

	FUNC,
	FUNCCALL,

	TYPED_IDENT,

	ADDROF,
	DEREF,
};


/**
 * visitor for easier extensibility
 */
class ASTVisitor
{
public:
	virtual ~ASTVisitor() = default;

	virtual void visit(const ASTToken<t_lval>* ast, std::size_t level) = 0;
	virtual void visit(const ASTToken<std::string>* ast, std::size_t level) = 0;
	virtual void visit(const ASTToken<t_real>* ast, std::size_t level) = 0;
	virtual void visit(const ASTToken<t_int>* ast, std::size_t level) = 0;
	virtual void visit(const ASTToken<void*>* ast, std::size_t level) = 0;
	virtual void visit(const ASTUnary* ast, std::size_t level) = 0;
	virtual void visit(const ASTBinary* ast, std::size_t level) = 0;
	virtual void visit(const ASTList* ast, std::size_t level) = 0;
	virtual void visit(const ASTCondition* ast, std::size_t level) = 0;
	virtual void visit(const ASTLoop* ast, std::size_t level) = 0;
	virtual void visit(const ASTFunc* ast, std::size_t level) = 0;
	virtual void visit(const ASTFuncCall* ast, std::size_t level) = 0;
	virtual void visit(const ASTJump* ast, std::size_t level) = 0;
	virtual void visit(const ASTTypedIdent* ast, std::size_t level) = 0;
	virtual void visit(const ASTAddrOf* ast, std::size_t level) = 0;
	virtual void visit(const ASTDeref* ast, std::size_t level) = 0;
};


/**
 * mutable visitor
 */
class ASTMutableVisitor
{
public:
	virtual ~ASTMutableVisitor() = default;

	virtual void visit(ASTToken<t_lval>* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTToken<std::string>* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTToken<t_real>* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTToken<t_int>* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTToken<void*>* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTUnary* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTBinary* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTList* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTCondition* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTLoop* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTFunc* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTFuncCall* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTJump* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTTypedIdent* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTAddrOf* ast, std::size_t level, bool gen_code) = 0;
	virtual void visit(ASTDeref* ast, std::size_t level, bool gen_code) = 0;
};


/**
 * get the source line number range of child node lines
 */
template<class t_line_range, class t_opt_range = std::optional<t_line_range>>
t_opt_range get_minmax_lines(const std::vector<t_opt_range>& lines)
{
	using t_line = std::decay_t<decltype(std::get<0>(t_line_range{}))>;
	t_opt_range range;

	for(const auto& line : lines)
	{
		if(!line)
			continue;
		if(!range)
			range = t_line_range(std::numeric_limits<t_line>::max(), t_line(0));

		std::get<0>(*range) = std::min(std::get<0>(*line), std::get<0>(*range));
		std::get<1>(*range) = std::max(std::get<1>(*line), std::get<1>(*range));
	}

	return range;
}


/**
 * syntax tree base
 */
class ASTBase : public lalr1::ASTBase
{
public:
	using t_line_range = std::pair<std::size_t, std::size_t>;


public:
	ASTBase(std::size_t id, std::optional<std::size_t> tableidx=std::nullopt)
		: lalr1::ASTBase{id, tableidx}
	{}

	virtual ~ASTBase() = default;

	virtual bool IsTerminal() const override { return false; };
	virtual ASTType GetType() const = 0;

	virtual VMType GetDataType() const { return m_datatype; }
	virtual void SetDataType(VMType ty) { m_datatype = ty; }

	// derive the associated data type (for casting)
	virtual void DeriveDataType();

	// assigns the source line numbers from the token lines
	virtual void AssignLineNumbers();

	virtual void Optimise() {}

	virtual std::size_t NumChildren() const { return 0; }
	virtual t_astbaseptr GetChild(std::size_t) const { return nullptr; }
	virtual void SetChild(std::size_t, const t_astbaseptr&) { }

	virtual void accept(ASTVisitor* visitor, std::size_t level = 0) const = 0;
	virtual void accept(ASTMutableVisitor* visitor, std::size_t level = 0, bool gen_code = true) = 0;


private:
	VMType m_datatype{VMType::UNKNOWN};
};



/**
 * visitor acceptor
 */
template<class t_ast_sub>
class ASTBaseAcceptor : public ASTBase
{
public:
	ASTBaseAcceptor(std::size_t id, std::optional<std::size_t> tableidx=std::nullopt)
		: ASTBase{id, tableidx}
	{}

	virtual void accept(ASTVisitor* visitor, std::size_t level = 0) const override
	{
		const t_ast_sub *sub = static_cast<const t_ast_sub*>(this);
		visitor->visit(sub, level);
	}

	virtual void accept(ASTMutableVisitor* visitor, std::size_t level = 0, bool gen_code = true) override
	{
		t_ast_sub *sub = static_cast<t_ast_sub*>(this);
		visitor->visit(sub, level, gen_code);
	}
};



/**
 * terminal symbols from lexer
 */
template<class t_lval>
class ASTToken : public ASTBaseAcceptor<ASTToken<t_lval>>
{
public:
	ASTToken(std::size_t id, std::size_t tableidx, std::size_t line)
		: ASTBaseAcceptor<ASTToken<t_lval>>{id, tableidx}, m_lexval{std::nullopt}
	{
		ASTBase::SetLineRange(std::make_pair(line, line));
	}

	ASTToken(std::size_t id, std::size_t tableidx, t_lval lval, std::size_t line)
		: ASTBaseAcceptor<ASTToken<t_lval>>{id, tableidx}, m_lexval{lval}
	{
		ASTBase::SetLineRange(std::make_pair(line, line));
	}

	virtual ~ASTToken() = default;

	virtual bool IsTerminal() const override
	{
		std::optional<bool> term_override = lalr1::ASTBase::GetTerminalOverride();
		if(term_override)
			return *term_override;
		return true;
	}

	virtual ASTType GetType() const override { return ASTType::TOKEN; }

	// get the lexical value of the token's attribute
	const t_lval& GetLexerValue() const { return *m_lexval; }
	void SetLexerValue(const t_lval& lval) { m_lexval = lval; }
	constexpr bool HasLexerValue() const { return m_lexval.operator bool(); }

	bool IsLValue() const { return m_islval; }
	void SetLValue(bool b) { m_islval = b; }

	bool IsIdent() const { return m_isident; }
	void SetIdent(bool b) { m_isident = b; }


private:
	std::optional<t_lval> m_lexval{};  // lexer value
	bool m_islval{false};  // names an l-value variable (on lhs of assignment)
	bool m_isident{false}; // is this token a variable identifier (or a literal)?
};



/**
 * node for unary operations
 */
class ASTUnary : public ASTBaseAcceptor<ASTUnary>
{
public:
	ASTUnary(std::size_t id, std::size_t tableidx, const t_astbaseptr& arg, std::size_t opid)
		: ASTBaseAcceptor<ASTUnary>{id, tableidx}, m_arg{arg}, m_opid{opid}
	{}

	virtual ~ASTUnary() = default;

	virtual ASTType GetType() const override { return ASTType::UNARY; }
	std::size_t GetOpId() const { return m_opid; }

	virtual std::size_t NumChildren() const override { return 1; }
	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		return i==0 ? m_arg : nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		if(i==0)
			m_arg = ast;
	}


private:
	t_astbaseptr m_arg{};
	std::size_t m_opid{};
};



/**
 * node for binary operations
 */
class ASTBinary : public ASTBaseAcceptor<ASTBinary>
{
public:
	ASTBinary(std::size_t id, std::size_t tableidx,
		const t_astbaseptr& arg1, const t_astbaseptr& arg2,
		std::size_t opid)
		: ASTBaseAcceptor<ASTBinary>{id, tableidx},
		  m_arg1{arg1}, m_arg2{arg2}, m_opid{opid}
	{}

	virtual ~ASTBinary() = default;

	virtual ASTType GetType() const override { return ASTType::BINARY; }
	std::size_t GetOpId() const { return m_opid; }

	virtual std::size_t NumChildren() const override { return 2; }

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_arg1;
			case 1: return m_arg2;
		}

		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_arg1 = ast; break;
			case 1: m_arg2 = ast; break;
		}
	}


private:
	t_astbaseptr m_arg1{}, m_arg2{};
	std::size_t m_opid{};
};



/**
 * list node, e.g. for statements
 */
class ASTList : public ASTBaseAcceptor<ASTList>
{
public:
	ASTList(std::size_t id, std::size_t tableidx)
		: ASTBaseAcceptor<ASTList>{id, tableidx}
	{}

	virtual ~ASTList() = default;

	virtual ASTType GetType() const override { return ASTType::LIST; }

	virtual std::size_t NumChildren() const override
	{
		return m_children.size();
	}

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		if(i >= m_children.size())
			return nullptr;
		return m_children[i];
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		if(i >= m_children.size())
			return;
		m_children[i] = ast;
	}

	void AddChild(const t_astbaseptr& ast, bool front = false)
	{
		if(front)
			m_children.insert(m_children.begin(), ast);
		else
			m_children.push_back(ast);
	}


private:
	std::vector<t_astbaseptr> m_children{};
};



/**
 * node for condition statements
 */
class ASTCondition : public ASTBaseAcceptor<ASTCondition>
{
public:
	ASTCondition(std::size_t id, std::size_t tableidx,
		const t_astbaseptr& cond, const t_astbaseptr& ifblock)
		: ASTBaseAcceptor<ASTCondition>{id, tableidx},
			m_cond{cond}, m_ifblock{ifblock}
	{}

	ASTCondition(std::size_t id, std::size_t tableidx,
		const t_astbaseptr& cond, const t_astbaseptr& ifblock, const t_astbaseptr& elseblock)
		: ASTBaseAcceptor<ASTCondition>{id, tableidx},
			m_cond{cond}, m_ifblock{ifblock}, m_elseblock{elseblock}
	{}

	virtual ~ASTCondition() = default;

	virtual ASTType GetType() const override { return ASTType::CONDITION; }

	virtual std::size_t NumChildren() const override { return m_elseblock ? 3 : 2; }

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_cond;
			case 1: return m_ifblock;
			case 2: return m_elseblock;
		}

		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_cond = ast; break;
			case 1: m_ifblock = ast; break;
			case 2: m_elseblock = ast; break;
		}
	}

	t_astbaseptr GetCondition() const { return m_cond; }
	t_astbaseptr GetIfBlock() const { return m_ifblock; }
	t_astbaseptr GetElseBlock() const { return m_elseblock; }

	void SetCondition(const t_astbaseptr& ast) { m_cond = ast; }
	void SetIfBlock(const t_astbaseptr& ast) { m_ifblock = ast; }
	void SetElseBlock(const t_astbaseptr& ast) { m_elseblock = ast; }


private:
	t_astbaseptr m_cond{}, m_ifblock{}, m_elseblock{};
};



/**
 * node for loop statements
 */
class ASTLoop : public ASTBaseAcceptor<ASTLoop>
{
public:
	ASTLoop(std::size_t id, std::size_t tableidx,
		const t_astbaseptr& cond, const t_astbaseptr& block)
		: ASTBaseAcceptor<ASTLoop>{id, tableidx},
			m_cond{cond}, m_block{block}
	{}

	virtual ~ASTLoop() = default;

	virtual ASTType GetType() const override { return ASTType::LOOP; }

	virtual std::size_t NumChildren() const override { return 2; }

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_cond;
			case 1: return m_block;
		}

		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_cond = ast; break;
			case 1: m_block = ast; break;
		}
	}

	t_astbaseptr GetCondition() const { return m_cond; }
	t_astbaseptr GetBlock() const { return m_block; }

	void SetCondition(const t_astbaseptr& ast) { m_cond = ast; }
	void SetBlock(const t_astbaseptr& ast) { m_block = ast; }


private:
	t_astbaseptr m_cond{}, m_block{};
};



/**
 * node for functions
 */
class ASTFunc : public ASTBaseAcceptor<ASTFunc>
{
public:
	ASTFunc(std::size_t id, std::size_t tableidx,
		const std::string& name,
		const t_astbaseptr& args, const t_astbaseptr& block)
		: ASTBaseAcceptor<ASTFunc>{id, tableidx},
			m_name{name}, m_args{args}, m_block{block}
	{}

	virtual ~ASTFunc() = default;

	virtual ASTType GetType() const override { return ASTType::FUNC; }

	virtual std::size_t NumChildren() const override { return 2; }

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_args;
			case 1: return m_block;
		}

		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_args = ast; break;
			case 1: m_block = ast; break;
		}
	}

	t_astbaseptr GetArgs() const { return m_args; }
	t_astbaseptr GetBlock() const { return m_block; }
	const std::string& GetName() const { return m_name; }

	void SetArgs(const t_astbaseptr& ast) { m_args = ast; }
	void SetBlock(const t_astbaseptr& ast) { m_block = ast; }
	void SetName(const std::string& name) { m_name = name; }

	/**
	 * get the number of function arguments
	 */
	std::size_t NumArgs() const
	{
		if(!m_args)
			return 0;

		if(m_args->GetType() != ASTType::LIST)
			return 1;

		if(auto arglist = std::dynamic_pointer_cast<ASTList>(m_args); arglist)
		{
			return arglist->NumChildren();
		}

		return 0;
	}


private:
	std::string m_name{};
	t_astbaseptr m_args{};
	t_astbaseptr m_block{};
};



/**
 * node for function calls
 */
class ASTFuncCall : public ASTBaseAcceptor<ASTFuncCall>
{
public:
	ASTFuncCall(std::size_t id, std::size_t tableidx,
		const std::string& name, const t_astbaseptr& args)
		: ASTBaseAcceptor<ASTFuncCall>{id, tableidx},
			m_name{name}, m_args{args}
	{}

	virtual ~ASTFuncCall() = default;

	virtual ASTType GetType() const override { return ASTType::FUNCCALL; }

	virtual std::size_t NumChildren() const override { return 1; }

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_args;
		}

		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_args = ast; break;
		}
	}

	t_astbaseptr GetArgs() const { return m_args; }
	const std::string& GetName() const { return m_name; }

	void SetArgs(const t_astbaseptr& ast) { m_args = ast; }
	void SetName(const std::string& name) { m_name = name; }

	/**
	 * get the number of function arguments
	 */
	std::size_t NumArgs() const
	{
		if(!m_args)
			return 0;

		if(m_args->GetType() != ASTType::LIST)
			return 1;

		if(auto arglist = std::dynamic_pointer_cast<ASTList>(m_args); arglist)
		{
			return arglist->NumChildren();
		}

		return 0;
	}


private:
	std::string m_name{};
	t_astbaseptr m_args{};
};



/**
 * node for jump keywords
 */
class ASTJump : public ASTBaseAcceptor<ASTJump>
{
public:
	enum class JumpType
	{
		UNKNOWN,
		RETURN,
		BREAK,
		CONTINUE
	};


public:
	ASTJump(std::size_t id, std::size_t tableidx,
		JumpType ty, const t_astbaseptr& expr = nullptr)
		: ASTBaseAcceptor<ASTJump>{id, tableidx},
			m_jumptype{ty}, m_expr{expr}
	{}

	virtual ~ASTJump() = default;

	virtual ASTType GetType() const override { return ASTType::JUMP; }

	JumpType GetJumpType() const { return m_jumptype; }
	void SetJumpType(JumpType ty) { m_jumptype = ty; }

	virtual std::size_t NumChildren() const override { return 1; }

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_expr;
		}

		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_expr = ast; break;
		}
	}

	t_astbaseptr GetExpr() const { return m_expr; }
	void SetExpr(const t_astbaseptr& ast) { m_expr = ast; }


private:
	JumpType m_jumptype{JumpType::UNKNOWN};
	t_astbaseptr m_expr{};
};



/**
 * identifier with a type declaration
 */
class ASTTypedIdent : public ASTBaseAcceptor<ASTTypedIdent>
{
public:
	ASTTypedIdent(std::size_t id, std::size_t tableidx,
		const t_astbaseptr& ident = nullptr)
		: ASTBaseAcceptor<ASTTypedIdent>{id, tableidx},
			m_ident{ident}
	{}

	virtual ~ASTTypedIdent() = default;

	virtual ASTType GetType() const override { return ASTType::TYPED_IDENT; }

	virtual std::size_t NumChildren() const override { return 1; }

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_ident;
		}

		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_ident = ast; break;
		}
	}

	t_astbaseptr GetIdent() const { return m_ident; }
	void SetIdent(const t_astbaseptr& ast) { m_ident = ast; }


private:
	t_astbaseptr m_ident{};
};



/**
 * node for variable/function address
 */
class ASTAddrOf : public ASTBaseAcceptor<ASTAddrOf>
{
public:
	ASTAddrOf(std::size_t id, std::size_t tableidx,
		const std::string& name)
		: ASTBaseAcceptor<ASTAddrOf>{id, tableidx},
			m_name{name}
	{}

	virtual ~ASTAddrOf() = default;

	virtual ASTType GetType() const override { return ASTType::ADDROF; }
	virtual VMType GetDataType() const override { return VMType::INT; }

	const std::string& GetName() const { return m_name; }
	void SetName(const std::string& name) { m_name = name; }


private:
	std::string m_name{};  // name of the variable or function
};



/**
 * node for dereferencing addresses
 */
class ASTDeref : public ASTBaseAcceptor<ASTDeref>
{
public:
	ASTDeref(std::size_t id, std::size_t tableidx,
		const t_astbaseptr& arg, const t_astbaseptr& expr = nullptr)
		: ASTBaseAcceptor<ASTDeref>{id, tableidx},
			m_arg{arg}, m_expr{expr}
	{}

	virtual ~ASTDeref() = default;

	virtual ASTType GetType() const override { return ASTType::DEREF; }

	virtual std::size_t NumChildren() const override
	{
		if(m_expr)
			return 2;
		return 1;
	}

	virtual t_astbaseptr GetChild(std::size_t i) const override
	{
		switch(i)
		{
			case 0: return m_arg;
			case 1: return m_expr;
		}
		return nullptr;
	}

	virtual void SetChild(std::size_t i, const t_astbaseptr& ast) override
	{
		switch(i)
		{
			case 0: m_arg = ast; break;
			case 1: m_expr = ast; break;
		}
	}

	bool IsLValue() const
	{
		// if there's an rhs expression, this is an lvalue
		return m_expr.operator bool();
	}


private:
	t_astbaseptr m_arg{};   // address to dereference
	t_astbaseptr m_expr{};  // rhs in case of assignment
};


#endif
