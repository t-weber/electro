/**
 * simple LL(1) expression parser
 *
 * @author Tobias Weber
 * @date 14-mar-2020, 8-may-2021
 * @license see 'LICENSE' file
 *
 * References:
 *	- https://www.cs.uaf.edu/~cs331/notes/FirstFollow.pdf
 *	- https://de.wikipedia.org/wiki/LL(k)-Grammatik
 *	- "Übersetzerbau", ISBN: 978-3540653899 (1999, 2013)
 */

#ifndef __EXPR_PARSER_H__
#define __EXPR_PARSER_H__


//#define EXPR_RUN_TEST
#define EXPR_PARSER_USE_INTEGER
#define EXPR_PARSER_NO_FUNCTIONS
#define EXPR_PARSER_NO_MATHLIB
#define EXPR_PARSER_NO_STDIO


/* value type */
#include "defines.h"

#ifdef EXPR_PARSER_USE_INTEGER
	typedef t_int t_value;
#else
	typedef t_real t_value;
#endif


#define MAX_IDENT 255


struct Symbol
{
	char name[MAX_IDENT];
	t_value value;

	struct Symbol* next;
};


struct ParserContext
{
	int lookahead;
	t_value lookahead_val;
	char lookahead_text[MAX_IDENT];

	int input_idx;
	int input_len;
	const char* input;

	struct Symbol symboltable;
};


extern void init_parser(struct ParserContext*);
extern void deinit_parser(struct ParserContext*);

extern t_value parse(struct ParserContext*, const char* str);
extern void print_symbols(struct ParserContext*);


#endif
