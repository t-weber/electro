/**
 * grammar of the compiler
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 08-jun-2022
 * @license see 'LICENSE' file
 */

#include "grammar.h"
#include "lexer.h"
#include "ast.h"


using t_lalrastbaseptr = lalr1::t_astbaseptr;
using lalr1::Terminal;
using lalr1::NonTerminal;
using lalr1::t_semanticargs;
using lalr1::t_semantic_id;
using lalr1::g_eps;


// TODO: determine and assign symbol data types

void ScriptGrammar::CreateGrammar(bool add_rules, bool add_semantics)
{
	// non-terminals
	start = std::make_shared<NonTerminal>(START, "start");
	stmts = std::make_shared<NonTerminal>(STMTS, "stmts");
	stmt = std::make_shared<NonTerminal>(STMT, "stmt");
	exprs = std::make_shared<NonTerminal>(EXPRS, "exprs");
	expr = std::make_shared<NonTerminal>(EXPR, "expr");
	bool_expr = std::make_shared<NonTerminal>(BOOL_EXPR, "bool_expr");
	idents = std::make_shared<NonTerminal>(IDENTS, "idents");
	typed_ident = std::make_shared<NonTerminal>(TYPED_IDENT, "typed_ident");

	// terminals
	op_assign = std::make_shared<Terminal>('=', "=");
	op_derefassign = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::DEREF_ASSIGN), "<<=");
	op_plus = std::make_shared<Terminal>('+', "+");
	op_minus = std::make_shared<Terminal>('-', "-");
	op_mult = std::make_shared<Terminal>('*', "*");
	op_div = std::make_shared<Terminal>('/', "/");
	op_mod = std::make_shared<Terminal>('%', "%");
	op_pow = std::make_shared<Terminal>('^', "^");

	op_equ = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::EQU), "==");
	op_nequ = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::NEQU), "!=");
	op_gequ = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::GEQU), ">=");
	op_lequ = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::LEQU), "<=");
	op_and = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::AND), "&&");
	op_or = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::OR), "||");
	op_gt = std::make_shared<Terminal>('>', ">");
	op_lt = std::make_shared<Terminal>('<', "<");
	op_not = std::make_shared<Terminal>('!', "!");
	op_binand = std::make_shared<Terminal>('&', "&");
	op_binor = std::make_shared<Terminal>('|', "|");
	op_binnot = std::make_shared<Terminal>('~', "~");
	op_binxor = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::BIN_XOR), "xor");

	op_shift_left = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::SHIFT_LEFT), "<<");
	op_shift_right = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::SHIFT_RIGHT), ">>");

	bracket_open = std::make_shared<Terminal>('(', "(");
	bracket_close = std::make_shared<Terminal>(')', ")");
	block_begin = std::make_shared<Terminal>('{', "{");
	block_end = std::make_shared<Terminal>('}', "}");

	comma = std::make_shared<Terminal>(',', ",");
	colon = std::make_shared<Terminal>(':', ":");
	stmt_end = std::make_shared<Terminal>(';', ";");

	sym_real = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::REAL), "real");
	sym_int = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::INT), "integer");
	sym_str = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::STR), "string");
	ident = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::IDENT), "ident");

	keyword_if = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::IF), "if");
	keyword_else = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::ELSE), "else");

	keyword_loop = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::LOOP), "loop");
	keyword_continue = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::CONTINUE), "continue");
	keyword_break = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::BREAK), "break");

	keyword_func = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::FUNC), "func");
	keyword_return = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::RETURN), "return");

	keyword_int = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::INT_DECL), "int");
	keyword_real = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::REAL_DECL), "real");

	op_addrof = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::ADDROF), "addrof");
	op_deref = std::make_shared<Terminal>(static_cast<t_symbol_id>(Token::DEREF), "deref");


	// operator precedences and associativities
	// see: https://en.cppreference.com/w/c/language/operator_precedence
	op_assign->SetPrecedence(10, 'r');
	op_derefassign->SetPrecedence(10, 'r');

	op_or->SetPrecedence(20, 'l');
	op_and->SetPrecedence(21, 'l');

	op_binor->SetPrecedence(30, 'l');
	op_binxor->SetPrecedence(31, 'l');
	op_binand->SetPrecedence(32, 'l');

	op_equ->SetPrecedence(40, 'l');
	op_nequ->SetPrecedence(40, 'l');

	op_lt->SetPrecedence(50, 'l');
	op_gt->SetPrecedence(50, 'l');
	op_gequ->SetPrecedence(50, 'l');
	op_lequ->SetPrecedence(50, 'l');

	op_shift_left->SetPrecedence(60, 'l');
	op_shift_right->SetPrecedence(60, 'l');

	op_plus->SetPrecedence(70, 'l');
	op_minus->SetPrecedence(70, 'l');

	op_mult->SetPrecedence(80, 'l');
	op_div->SetPrecedence(80, 'l');
	op_mod->SetPrecedence(80, 'l');

	op_not->SetPrecedence(90, 'l');
	op_binnot->SetPrecedence(100, 'l');

	op_pow->SetPrecedence(110, 'r');

	op_addrof->SetPrecedence(120, 'l');
	op_deref->SetPrecedence(120, 'l');


	// rule id number
	t_semantic_id semanticindex = 0;

	// rule: start -> stmts
	if(add_rules)
	{
		start->AddRule({ stmts }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;
			return args[0];
		}));
	}
	++semanticindex;


	// rule: expr -> expr + expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_plus, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(expr->GetId(), 0, arg1, arg2, op_plus->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr - expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_minus, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(expr->GetId(), 0, arg1, arg2, op_minus->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr * expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_mult, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(expr->GetId(), 0, arg1, arg2, op_mult->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr / expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_div, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(expr->GetId(), 0, arg1, arg2, op_div->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr % expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_mod, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(expr->GetId(), 0, arg1, arg2, op_mod->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr ^ expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_pow, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(expr->GetId(), 0, arg1, arg2, op_pow->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> ( expr )
	if(add_rules)
	{
		expr->AddRule({ bracket_open, expr, bracket_close }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;
			return args[1];
		}));
	}
	++semanticindex;


	// rule: function call, expr -> ident( exprs )
	if(add_rules)
	{
		expr->AddRule({ ident, bracket_open, exprs, bracket_close }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsident = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr rhsexprs = std::dynamic_pointer_cast<ASTBase>(args[2]);

			if(rhsident->GetType() != ASTType::TOKEN)
				throw std::runtime_error("Expected a function name.");

			auto funcname = std::dynamic_pointer_cast<ASTToken<std::string>>(rhsident);
			funcname->SetIdent(true);
			const std::string& name = funcname->GetLexerValue();

			auto funccall = std::make_shared<ASTFuncCall>(expr->GetId(), 0, name, rhsexprs);
			funccall->SetLineRange(funcname->GetLineRange());
			return funccall;
		}));
	}
	++semanticindex;


	// rule: expr -> real symbol
	if(add_rules)
	{
		expr->AddRule({ sym_real }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr sym = std::dynamic_pointer_cast<ASTBase>(args[0]);
			sym->SetDataType(VMType::REAL);
			sym->SetId(expr->GetId());
			sym->SetTerminalOverride(false);  // expression, no terminal any more
			return sym;
		}));
	}
	++semanticindex;


	// rule: expr -> int symbol
	if(add_rules)
	{
		expr->AddRule({ sym_int }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr sym = std::dynamic_pointer_cast<ASTBase>(args[0]);
			sym->SetDataType(VMType::INT);
			sym->SetId(expr->GetId());
			sym->SetTerminalOverride(false);  // expression, no terminal any more
			return sym;
		}));
	}
	++semanticindex;


	// rule: expr -> string symbol
	/*if(add_rules)
	{
		expr->AddRule({ sym_str }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr sym = std::dynamic_pointer_cast<ASTBase>(args[0]);
			sym->SetDataType(VMType::STR);
			sym->SetId(expr->GetId());
			sym->SetTerminalOverride(false);  // expression, no terminal any more
			return sym;
		}));
	}
	++semanticindex;*/


	// rule: expr -> ident
	if(add_rules)
	{
		expr->AddRule({ ident }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto rhsident = std::dynamic_pointer_cast<ASTToken<std::string>>(args[0]);
			rhsident->SetIdent(true);
			rhsident->SetId(expr->GetId());
			rhsident->SetTerminalOverride(false);  // expression, no terminal any more
			return rhsident;
		}));
	}
	++semanticindex;


	// rule: unary-: expr -> -expr
	if(add_rules)
	{
		expr->AddRule({ op_minus, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr expr = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTUnary>(expr->GetId(), 0, expr, op_minus->GetId());
		}));
	}
	++semanticindex;


	// rule: unary+: expr -> +expr
	if(add_rules)
	{
		expr->AddRule({ op_plus, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTUnary>(expr->GetId(), 0, rhsexpr, op_plus->GetId());
		}));
	}
	++semanticindex;


	// rule: assignment: expr -> typed_ident = expr
	if(add_rules)
	{
		expr->AddRule({ typed_ident, op_assign, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto _lhsident = std::dynamic_pointer_cast<ASTTypedIdent>(args[0]);
			VMType datatype = _lhsident->GetDataType();
			t_astbaseptr lhsident = std::dynamic_pointer_cast<ASTBase>(_lhsident->GetIdent());
			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[2]);

			if(datatype != rhsexpr->GetDataType() && rhsexpr->GetDataType() != VMType::UNKNOWN)
			{
				// TODO: convert type

				std::ostringstream ostrerr;
				ostrerr << "Mismatching type, expected " << get_vm_type_name(datatype)
					<< ", got " << get_vm_type_name(rhsexpr->GetDataType()) << ".";
				throw std::runtime_error(ostrerr.str());
			}

			if(lhsident->GetType() != ASTType::TOKEN)
			{
				throw std::runtime_error(
					"Expected a symbol name on lhs of assignment.");
			}

			auto symname = std::dynamic_pointer_cast<ASTToken<std::string>>(lhsident);
			symname->SetIdent(true);
			symname->SetLValue(true);
			symname->SetDataType(/*rhsexpr->GetDataType()*/ datatype);
			//std::cout << "assigning " << symname->GetLexerValue() << std::endl;

			return std::make_shared<ASTBinary>(
				expr->GetId(), 0, rhsexpr, symname, op_assign->GetId());
		}));
	}
	++semanticindex;


	// rule: stmts -> stmt stmts
	if(add_rules)
	{
		stmts->AddRule({ stmt, stmts }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto stmts_lst = std::dynamic_pointer_cast<ASTList>(args[1]);
			t_astbaseptr rhsstmt = std::dynamic_pointer_cast<ASTBase>(args[0]);
			stmts_lst->AddChild(rhsstmt, true);
			return stmts_lst;
		}));
	}
	++semanticindex;


	// rule: stmts -> eps
	if(add_rules)
	{
		stmts->AddRule({ g_eps }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, [[maybe_unused]] const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			return std::make_shared<ASTList>(stmts->GetId(), 0);
		}));
	}
	++semanticindex;


	// rule: stmt -> expr ;
	if(add_rules)
	{
		stmt->AddRule({ expr, stmt_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			args[0]->SetId(stmt->GetId());
			return args[0];
		}));
	}
	++semanticindex;


	// rule: stmt -> if(bool_expr) { stmts }
	if(add_rules)
	{
		stmt->AddRule({ keyword_if, bracket_open, bool_expr, bracket_close,
			block_begin, stmts, block_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[2]);
			t_astbaseptr rhsstmts = std::dynamic_pointer_cast<ASTBase>(args[5]);
			return std::make_shared<ASTCondition>(stmt->GetId(), 0, rhsexpr, rhsstmts);
		}));
	}
	++semanticindex;


	// rule: stmt -> if(bool_expr) { stmts } else { stmts }
	if(add_rules)
	{
		stmt->AddRule({ keyword_if, bracket_open, bool_expr, bracket_close,
			block_begin, stmts, block_end,
			keyword_else, block_begin, stmts, block_end}, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[2]);
			t_astbaseptr rhsstmts = std::dynamic_pointer_cast<ASTBase>(args[5]);
			t_astbaseptr rhselse_stmts = std::dynamic_pointer_cast<ASTBase>(args[9]);
			return std::make_shared<ASTCondition>(stmt->GetId(), 0, rhsexpr, rhsstmts, rhselse_stmts);
		}));
	}
	++semanticindex;


	// rule: stmt -> loop(bool_expr) { stmts }
	if(add_rules)
	{
		stmt->AddRule({ keyword_loop, bracket_open, bool_expr, bracket_close,
			block_begin, stmts, block_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[2]);
			t_astbaseptr rhsstmts = std::dynamic_pointer_cast<ASTBase>(args[5]);
			return std::make_shared<ASTLoop>(stmt->GetId(), 0, rhsexpr, rhsstmts);
		}));
	}
	++semanticindex;


	// rule: function definition: stmt -> func name ( idents ) { stmts }
	if(add_rules)
	{
		stmt->AddRule({ keyword_func, typed_ident, bracket_open, idents, bracket_close,
			block_begin, stmts, block_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto funcident = std::dynamic_pointer_cast<ASTTypedIdent>(args[1]);
			auto funcname = std::dynamic_pointer_cast<ASTToken<std::string>>(funcident->GetIdent());
			if(funcname->GetType() != ASTType::TOKEN)
				throw std::runtime_error("Expected a function name.");
			const std::string& ident = funcname->GetLexerValue();

			t_astbaseptr rhsidents = std::dynamic_pointer_cast<ASTBase>(args[3]);  // arguments
			t_astbaseptr rhsstmts = std::dynamic_pointer_cast<ASTBase>(args[6]);   // block
			t_astbaseptr func = std::make_shared<ASTFunc>(stmt->GetId(), 0, ident, rhsidents, rhsstmts);
			func->SetDataType(funcident->GetDataType());  // return data type
			func->SetLineRange(funcname->GetLineRange());

			//std::cout << ident << ": " << get_vm_type_name(func->GetDataType()) << std::endl;
			return func;
		}));
	}
	++semanticindex;


	// rule: stmt -> break ;
	if(add_rules)
	{
		stmt->AddRule({ keyword_break, stmt_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, [[maybe_unused]] const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto jump = std::make_shared<ASTJump>(stmt->GetId(), 0, ASTJump::JumpType::BREAK);
			jump->SetLineRange(args[0]->GetLineRange());
			return jump;
		}));
	}
	++semanticindex;


	// rule: stmt -> break symbol ;
	if(add_rules)
	{
		stmt->AddRule({ keyword_break, sym_int, stmt_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr sym = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTJump>(stmt->GetId(), 0, ASTJump::JumpType::BREAK, sym);
		}));
	}
	++semanticindex;


	// rule: stmt -> continue ;
	if(add_rules)
	{
		stmt->AddRule({ keyword_continue, stmt_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, [[maybe_unused]] const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto jump = std::make_shared<ASTJump>(stmt->GetId(), 0, ASTJump::JumpType::CONTINUE);
			jump->SetLineRange(args[0]->GetLineRange());
			return jump;
		}));
	}
	++semanticindex;


	// rule: stmt -> continue symbol ;
	if(add_rules)
	{
		stmt->AddRule({ keyword_continue, sym_int, stmt_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr sym = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTJump>(
				stmt->GetId(), 0, ASTJump::JumpType::CONTINUE, sym);
		}));
	}
	++semanticindex;


	// rule: stmt -> return ;
	if(add_rules)
	{
		stmt->AddRule({ keyword_return, stmt_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, [[maybe_unused]] const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto jump = std::make_shared<ASTJump>(stmt->GetId(), 0, ASTJump::JumpType::RETURN);
			jump->SetLineRange(args[0]->GetLineRange());
			return jump;
		}));
	}
	++semanticindex;


	// rule: stmt -> return expr ;
	if(add_rules)
	{
		stmt->AddRule({ keyword_return, expr, stmt_end }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTJump>(stmt->GetId(), 0, ASTJump::JumpType::RETURN, rhsexpr);
		}));
	}
	++semanticindex;


	// rule: bool_expr -> bool_expr and bool_expr
	if(add_rules)
	{
		bool_expr->AddRule({ bool_expr, op_and, bool_expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_and->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> bool_expr or bool_expr
	if(add_rules)
	{
		bool_expr->AddRule({ bool_expr, op_or, bool_expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_or->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> !bool_expr
	if(add_rules)
	{
		bool_expr->AddRule({ op_not, bool_expr, }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTUnary>(bool_expr->GetId(), 0, arg, op_not->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> ( bool_expr )
	if(add_rules)
	{
		bool_expr->AddRule({ bracket_open, bool_expr, bracket_close }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;
			return  args[1];
		}));
	}
	++semanticindex;


	// rule: bool_expr -> expr > expr
	if(add_rules)
	{
		bool_expr->AddRule({ expr, op_gt, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_gt->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> expr < expr
	if(add_rules)
	{
		bool_expr->AddRule({ expr, op_lt, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_lt->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> expr >= expr
	if(add_rules)
	{
		bool_expr->AddRule({ expr, op_gequ, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_gequ->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> expr <= expr
	if(add_rules)
	{
		bool_expr->AddRule({ expr, op_lequ, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_lequ->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> expr == expr
	if(add_rules)
	{
		bool_expr->AddRule({ expr, op_equ, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_equ->GetId());
		}));
	}
	++semanticindex;


	// rule: bool_expr -> expr != expr
	if(add_rules)
	{
		bool_expr->AddRule({ expr, op_nequ, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				bool_expr->GetId(), 0, arg1, arg2, op_nequ->GetId());
		}));
	}
	++semanticindex;


	// rule: idents -> typed_ident, idents
	if(add_rules)
	{
		idents->AddRule({ typed_ident, comma, idents }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto _rhsident = std::dynamic_pointer_cast<ASTTypedIdent>(args[0]);
			auto rhsident = std::dynamic_pointer_cast<ASTToken<std::string>>(_rhsident->GetIdent());

			auto idents_lst = std::dynamic_pointer_cast<ASTList>(args[2]);
			idents_lst->AddChild(rhsident, true);
			return idents_lst;
		}));
	}
	++semanticindex;


	// rule: idents -> typed_ident
	if(add_rules)
	{
		idents->AddRule({ typed_ident }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto _rhsident = std::dynamic_pointer_cast<ASTTypedIdent>(args[0]);
			auto rhsident = std::dynamic_pointer_cast<ASTToken<std::string>>(_rhsident->GetIdent());

			auto idents_lst = std::make_shared<ASTList>(idents->GetId(), 0);
			idents_lst->AddChild(rhsident, true);
			return idents_lst;
		}));
	}
	++semanticindex;


	// rule: idents -> eps
	if(add_rules)
	{
		idents->AddRule({ g_eps }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, [[maybe_unused]] const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			return std::make_shared<ASTList>(idents->GetId(), 0);
		}));
	}
	++semanticindex;


	// rule: typed_ident -> ident
	if(add_rules)
	{
		typed_ident->AddRule({ ident }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto rhsident = std::dynamic_pointer_cast<ASTToken<std::string>>(args[0]);
			rhsident->SetIdent(true);

			return std::make_shared<ASTTypedIdent>(typed_ident->GetId(), 0, rhsident);
		}));
	}
	++semanticindex;


	// rule: typed_ident -> ident : int
	if(add_rules)
	{
		typed_ident->AddRule({ ident, colon, keyword_int }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto rhsident = std::dynamic_pointer_cast<ASTToken<std::string>>(args[0]);
			rhsident->SetIdent(true);
			rhsident->SetDataType(VMType::INT);

			auto ident_ty = std::make_shared<ASTTypedIdent>(typed_ident->GetId(), 0, rhsident);
			ident_ty->SetDataType(VMType::INT);
			return ident_ty;
		}));
	}
	++semanticindex;


	// rule: typed_ident -> ident : real
	if(add_rules)
	{
		typed_ident->AddRule({ ident, colon, keyword_real }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			auto rhsident = std::dynamic_pointer_cast<ASTToken<std::string>>(args[0]);
			rhsident->SetIdent(true);
			rhsident->SetDataType(VMType::REAL);

			auto ident_ty = std::make_shared<ASTTypedIdent>(typed_ident->GetId(), 0, rhsident);
			ident_ty->SetDataType(VMType::REAL);
			return ident_ty;
		}));
	}
	++semanticindex;


	// rule: exprs -> expr, exprs
	if(add_rules)
	{
		exprs->AddRule({ expr, comma, exprs }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[0]);
			auto exprs_lst = std::dynamic_pointer_cast<ASTList>(args[2]);
			exprs_lst->AddChild(rhsexpr, false);
			return exprs_lst;
		}));
	}
	++semanticindex;


	// rule: exprs -> expr
	if(add_rules)
	{
		exprs->AddRule({ expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[0]);
			auto exprs_lst = std::make_shared<ASTList>(exprs->GetId(), 0);
			exprs_lst->AddChild(rhsexpr, false);
			return exprs_lst;
		}));
	}
	++semanticindex;


	// rule: exprs -> eps
	if(add_rules)
	{
		exprs->AddRule({ g_eps }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, [[maybe_unused]] const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			return std::make_shared<ASTList>(exprs->GetId(), 0);
		}));
	}
	++semanticindex;


	// rule: binary not: expr -> ~expr
	if(add_rules)
	{
		expr->AddRule({ op_binnot, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTUnary>(expr->GetId(), 0, arg, op_binnot->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr bin_and expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_binand, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				expr->GetId(), 0, arg1, arg2, op_binand->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr bin_or expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_binor, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				expr->GetId(), 0, arg1, arg2, op_binor->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr bin_xor expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_binxor, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				expr->GetId(), 0, arg1, arg2, op_binxor->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr << expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_shift_left, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				expr->GetId(), 0, arg1, arg2, op_shift_left->GetId());
		}));
	}
	++semanticindex;


	// rule: expr -> expr >> expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_shift_right, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg1 = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr arg2 = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTBinary>(
				expr->GetId(), 0, arg1, arg2, op_shift_right->GetId());
		}));
	}
	++semanticindex;


	// rule: dereferencing on lhs: expr -> expr deref_assign expr
	if(add_rules)
	{
		expr->AddRule({ expr, op_derefassign, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr argaddr = std::dynamic_pointer_cast<ASTBase>(args[0]);
			t_astbaseptr rhsexpr = std::dynamic_pointer_cast<ASTBase>(args[2]);
			return std::make_shared<ASTDeref>(expr->GetId(), 0, argaddr, rhsexpr);
		}));
	}
	++semanticindex;


	// rule: dereferencing on rhs: expr -> deref expr
	if(add_rules)
	{
		expr->AddRule({ op_deref, expr }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;

			t_astbaseptr arg = std::dynamic_pointer_cast<ASTBase>(args[1]);
			return std::make_shared<ASTDeref>(expr->GetId(), 0, arg);
		}));
	}
	++semanticindex;


	// rule: address of variable: expr -> addrof ident
	if(add_rules)
	{
		expr->AddRule({ op_addrof, ident }, semanticindex);
	}
	if(add_semantics)
	{
		rules.emplace(std::make_pair(semanticindex,
		[this](bool full_match, const t_semanticargs& args, [[maybe_unused]] t_lalrastbaseptr retval) -> t_lalrastbaseptr
		{
			if(!full_match) return nullptr;
			t_astbaseptr rhsident = std::dynamic_pointer_cast<ASTBase>(args[1]);

			if(rhsident->GetType() != ASTType::TOKEN)
				throw std::runtime_error("Expected a variable or function name.");

			auto identname = std::dynamic_pointer_cast<ASTToken<std::string>>(rhsident);
			identname->SetIdent(true);

			const std::string& name = identname->GetLexerValue();
			auto addrofnode = std::make_shared<ASTAddrOf>(expr->GetId(), 0, name);
			addrofnode->SetLineRange(identname->GetLineRange());
			return addrofnode;
		}));
	}
	++semanticindex;
}
