/**
 * simple lexer
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 7-mar-20
 * @license see 'LICENSE' file
 */

#ifndef __LR1_LEXER_H__
#define __LR1_LEXER_H__

#include <iostream>
#include <string>
#include <vector>
#include <utility>
#include <optional>

#include "ast.h"
#include "lval.h"
#include "lalr1/common.h"

using lalr1::t_symbol_id;
using lalr1::t_toknode;
using lalr1::t_mapIdIdx;
using lalr1::END_IDENT;


// [ token, lvalue, line number ]
using t_lexer_match = std::tuple<t_symbol_id, t_lval, std::size_t>;


enum class Token : t_symbol_id
{
	// constants
	REAL         = 1000,
	INT          = 1001,
	STR          = 1002,

	// variable identifiers
	IDENT        = 1100,

	// variable declarators
	INT_DECL     = 1200,
	REAL_DECL    = 1201,

	// comparison operators
	EQU          = 2000,
	NEQU         = 2001,
	GEQU         = 2002,
	LEQU         = 2003,

	// logical operators
	AND          = 2100,
	OR           = 2101,

	// binary operators
	BIN_XOR      = 2200,
	SHIFT_LEFT   = 2201,
	SHIFT_RIGHT  = 2202,

	// address operators
	ADDROF       = 2300,
	DEREF        = 2301,
	DEREF_ASSIGN = 2400,

	// conditionals
	IF           = 3000,
	ELSE         = 3001,

	// loops
	LOOP         = 3100,
	BREAK        = 3101,
	CONTINUE     = 3102,

	// functions
	FUNC         = 4000,
	RETURN       = 4001,

	// EOF
	END          = END_IDENT,
};


class Lexer
{
public:
	Lexer(std::istream* = &std::cin);

	// get all tokens and attributes
	std::vector<t_toknode> GetAllTokens();

	void SetEndOnNewline(bool b) { m_end_on_newline = b; }
	void SetIgnoreInt(bool b) { m_ignore_int = b; }
	void SetTermIdxMap(const t_mapIdIdx* map) { m_mapTermIdx = map; }


protected:
	// get next token and attribute
	t_lexer_match GetNextToken(std::size_t* line = nullptr);

	// find all matching tokens for input string
	std::vector<t_lexer_match> GetMatchingTokens(
		const std::string& str, std::size_t line);


private:
	bool m_end_on_newline{true};
	bool m_ignore_int{false};

	std::istream* m_istr{nullptr};
	const t_mapIdIdx* m_mapTermIdx{nullptr};
};


#endif
