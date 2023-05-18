/**
 * float test
 * @author Tobias Weber
 * @date 18-May-2023
 * @license see 'LICENSE' file
 */

#include "arb_float.h"


int main()
{
	ArbFloat f(32, 8);
	f.InterpretFrom<float>(-123.4);
	f.PrintInfos();
	std::cout << "--------------------------------------------------------------------------------\n";
	f.IncExp(3);
	f.PrintInfos();
	std::cout << "--------------------------------------------------------------------------------\n";
	f.IncExp(-3);
	f.PrintInfos();

	std::cout << "\nnative value:  " << f.InterpretAs<float>() << std::endl;

	return 0;
}
