/**
 * ast
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 14-jun-2022
 * @license see 'LICENSE' file
 */

#include "ast.h"


/**
 * assigns the source line numbers from the token lines
 */
void ASTBase::AssignLineNumbers()
{
	std::vector<std::optional<t_line_range>> lines;

	std::size_t children = NumChildren();
	for(std::size_t childidx=0; childidx<children; ++childidx)
	{
		const t_astbaseptr child = GetChild(childidx);
		if(!child)
			continue;

		child->AssignLineNumbers();
		lines.push_back(child->GetLineRange());
	}

	if(lines.size())
	{
		lines.push_back(GetLineRange());
		SetLineRange(get_minmax_lines<t_line_range>(lines));
	}
}


/**
 * derive the associated data type (for casting)
 */
void ASTBase::DeriveDataType()
{
	std::size_t children = NumChildren();
	for(std::size_t childidx=0; childidx<children; ++childidx)
	{
		const t_astbaseptr child = GetChild(childidx);
		if(!child)
			continue;

		if(child->GetDataType() == VMType::UNKNOWN)
			child->DeriveDataType();

		//std::cout << "child " << childidx << ": "
		//	<< get_vm_type_name(child->GetDataType())
		//	<< std::endl;
	}

	// set data type if it's not yet known
	if(GetDataType() == VMType::UNKNOWN)
	{
		if(children == 1)
		{
			const t_astbaseptr child = GetChild(0);
			if(child)
				SetDataType(child->GetDataType());
		}
		else if(children == 2)
		{
			const t_astbaseptr child1 = GetChild(0);
			const t_astbaseptr child2 = GetChild(1);

			if(child1 && child2)
			{
				VMType ty1 = child1->GetDataType();
				VMType ty2 = child2->GetDataType();
				bool type_set = false;

				if(GetType() == ASTType::BINARY)
				{
					ASTBinary* bin = dynamic_cast<ASTBinary*>(this);

					// use lhs variable type on assignments
					if(bin->GetOpId() == '=')
					{
						SetDataType(ty2);
						type_set = true;
					}
				}

				if(!type_set)
					SetDataType(derive_data_type(ty1, ty2));
			}
		}
	}
}
