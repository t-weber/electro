/**
 * ast optimisation
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 12-mar-2023
 * @license see 'LICENSE' file
 */

#ifndef __LR1_AST_OPT_H__
#define __LR1_AST_OPT_H__

#include "ast.h"


extern t_astbaseptr ast_optimise(t_astbaseptr& ast, std::size_t *opt_ctr = nullptr);


#endif
