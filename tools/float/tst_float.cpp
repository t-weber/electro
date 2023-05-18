/**
 * float test
 * @author Tobias Weber
 * @date 18-May-2023
 * @license see 'LICENSE' file
 */

#include "arb_float.h"


int main()
{
	ArbFloat<> f(32, 8);
	f.InterpretFrom<float>(-123.4f);
	f.PrintInfos();
	std::cout << "\nnative value:  " << f.InterpretAs<float>() << std::endl;
	std::cout << "--------------------------------------------------------------------------------\n";
	f.IncExp(3);
	f.PrintInfos();
	std::cout << "--------------------------------------------------------------------------------\n";
	f.IncExp(-3);
	f.PrintInfos();
	std::cout << "\nnative value:  " << f.InterpretAs<float>() << std::endl;

	std::cout << "\n================================================================================\n\n";

	ArbFloat<> d(64, 11);
	d.InterpretFrom<double>(-123.4);
	d.PrintInfos();
	std::cout << "\nnative value:  " << d.InterpretAs<double>() << std::endl;
	std::cout << "--------------------------------------------------------------------------------\n";
	d.IncExp(3);
	d.PrintInfos();
	std::cout << "--------------------------------------------------------------------------------\n";
	//d.IncExp(-3);
	d.Normalise();
	d.PrintInfos();
	std::cout << "\nnative value:  " << d.InterpretAs<double>() << std::endl;
	std::cout << "--------------------------------------------------------------------------------\n";
	d.Add(d);
	//d.Mult(d);
	//d.Div(d);
	d.PrintInfos();
	std::cout << "\nnative value:  " << d.InterpretAs<double>() << std::endl;

	return 0;
}
