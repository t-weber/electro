/**
 * ast optimisation
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 12-mar-2023
 * @license see 'LICENSE' file
 */

#include "ast_optimise.h"
#include "vm/helpers.h"



/**
 * optimise constant expressions in binary ast node
 */
template<class t_val>
t_astbaseptr ast_optimise_bin(std::shared_ptr<ASTBinary>& astbin, t_astbaseptr& _child1, t_astbaseptr& _child2)
{
	auto child1 = static_pointer_cast<ASTToken<t_val>>(_child1);
	auto child2 = static_pointer_cast<ASTToken<t_val>>(_child2);

	switch(astbin->GetOpId())
	{
		case '+':
		{
			child1->SetLexerValue(child1->GetLexerValue() + child2->GetLexerValue());
			return child1;
		}
		case '-':
		{
			child1->SetLexerValue(child1->GetLexerValue() - child2->GetLexerValue());
			return child1;
		}
		case '*':
		{
			child1->SetLexerValue(child1->GetLexerValue() * child2->GetLexerValue());
			return child1;
		}
		case '/':
		{
			child1->SetLexerValue(child1->GetLexerValue() / child2->GetLexerValue());
			return child1;
		}
		case '%':
		{
			if constexpr(std::is_same_v<t_val, t_int>)
			{
				child1->SetLexerValue(child1->GetLexerValue() % child2->GetLexerValue());
				return child1;
			}
			else if constexpr(std::is_same_v<t_val, t_real>)
			{
				child1->SetLexerValue(std::fmod(child1->GetLexerValue(), child2->GetLexerValue()));
				return child1;
			}
			break;
		}
		case '^':
		{
			child1->SetLexerValue(::pow<t_int>(child1->GetLexerValue(), child2->GetLexerValue()));
			return child1;
		}
		default:
			break;
	}

	// no optimisation
	return nullptr;
}



/**
 * optimise the ast
 */
t_astbaseptr ast_optimise(t_astbaseptr& ast, std::size_t *opt_ctr)
{
	for(std::size_t childidx=0; childidx<ast->NumChildren(); ++childidx)
	{
		auto child = ast->GetChild(childidx);
		auto new_child = ast_optimise(child, opt_ctr);
		ast->SetChild(childidx, new_child);
	}

	// simplify constant expressions
	if(ast->GetType() == ASTType::BINARY)
	{
		auto astbin = static_pointer_cast<ASTBinary>(ast);

		auto child1 = astbin->GetChild(0);
		auto child2 = astbin->GetChild(1);

		if(child1->GetType() == ASTType::TOKEN && child2->GetType() == ASTType::TOKEN
			&& child1->GetDataType() == child2->GetDataType())
		{
			t_astbaseptr newast = nullptr;

			switch(child1->GetDataType())
			{
				case VMType::INT:
					newast = ast_optimise_bin<t_int>(astbin, child1, child2);
					break;
				case VMType::REAL:
					newast = ast_optimise_bin<t_real>(astbin, child1, child2);
					break;
				default:
					break;
			}

			if(newast)
			{
				if(opt_ctr) ++*opt_ctr;
				return newast;
			}
		}
	}

	// nothing optimised, return original ast node
	return ast;
}
