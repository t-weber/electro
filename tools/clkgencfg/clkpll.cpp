/**
 * calculates pll values for clock generator ic
 * @author Tobias Weber
 * @date 21-April-2024
 * @license see 'LICENSE' file
 *
 * Reference:
 *   - [manual] https://www.skyworksinc.com/-/media/SkyWorks/SL/documents/public/reference-manuals/Si5338-RM.pdf
 *
 * g++ -std=c++20 -o clkpll clkpll.cpp -lboost_program_options
 */

#include <vector>
#include <tuple>
#include <algorithm>
#include <limits>
#include <iostream>
#include <iomanip>

#include <boost/program_options.hpp>
namespace args = boost::program_options;


using t_int = int;
using t_real = double;


struct ClockGenCfg
{
	t_int P = 1;
	t_int R = 1;

	t_real f_P = -1.;
	t_real f_V = -1.;
	t_real ms_n = -1.;

	t_real eps = -1.;
	t_int ms_n_p1 = -1;
	t_int ms_n_p2 = -1;
	t_int ms_n_p3 = -1;

	t_int k_phi = -1;
	t_int ms_cal = -1;
};


/**
 * find configuration parameters, see [manual, p. 6]
 */
ClockGenCfg find_clk_gen_cfg(
	t_real in_freq, t_real out_freq, bool in_freq_from_xtal)
{
	ClockGenCfg cfg;

	// step 1 in [manual, p. 6]
	// in_freq / P !<= 40 MHz
	if(in_freq_from_xtal)
		cfg.P = 1;
	else
		cfg.P = std::ceil(in_freq / 40.);

	cfg.f_P = in_freq / t_real(cfg.P);

	// step 2 in [manual, p. 6]
	// out_freq * R !>= 5 MHz
	if(out_freq < 5.)
		cfg.R = std::ceil(5. / out_freq);

	// step 3 in [manual, p. 6]
	t_real f_S = t_real(cfg.R) * out_freq;

	// step 4 in [manual, p. 6]
	std::vector<ClockGenCfg> possible_cfgs;
	for(t_int div = 4; div < 568; div += 2)
	{
		ClockGenCfg possible_cfg = cfg;

		possible_cfg.f_V = f_S * t_real(div);
		// f_V should be around 2500 MHz
		if(possible_cfg.f_V < 2200. || possible_cfg.f_V > 2840.)
			continue;

		// step 5 in [manual, p. 6]
		possible_cfg.ms_n = possible_cfg.f_V / possible_cfg.f_P;

		if(possible_cfg.ms_n >= 8. || possible_cfg.ms_n == 4. || possible_cfg.ms_n == 6.)
			possible_cfgs.emplace_back(std::move(possible_cfg));
	}

	if(possible_cfgs.size() == 0)
	{
		std::cerr << "Error: No possible configuration found." << std::endl;
		return cfg;
	}

	// get configuration with value closest to integer
	std::stable_sort(possible_cfgs.begin(), possible_cfgs.end(),
		[](const ClockGenCfg& cfg1, const ClockGenCfg& cfg2) -> bool
	{
		return std::abs(cfg1.ms_n - std::round(cfg1.ms_n))
			< std::abs(cfg2.ms_n - std::round(cfg2.ms_n));
	});

	cfg = possible_cfgs[0];


	t_int intval = t_int(cfg.ms_n);
	t_real remainder = cfg.ms_n - t_real(intval);

	using t_fraction = std::tuple<t_int, t_int, t_real>;
	std::vector<t_fraction> fractions;

	// try powers of 2
	for(t_int denom_pow = 0; denom_pow < 30; ++denom_pow)
	{
		t_int denom = 1 << denom_pow;
		t_int num = t_int(remainder * denom);

		t_real eps = std::abs(remainder - t_real(num) / t_real(denom));

		fractions.push_back(std::make_tuple(num, denom, eps));
	}

	// try powers of 10
	for(t_int denom_pow = 0; denom_pow < 10; ++denom_pow)
	{
		t_int denom = std::pow(10, denom_pow);
		t_int num = t_int(remainder * denom);

		t_real eps = std::abs(remainder - t_real(num) / t_real(denom));

		fractions.push_back(std::make_tuple(num, denom, eps));
	}

	// get fraction with lowest eps
	std::stable_sort(fractions.begin(), fractions.end(),
		[](const t_fraction& frac1, const t_fraction& frac2) -> bool
	{
		return std::get<2>(frac1) < std::get<2>(frac2);
	});

	auto [num, denom, eps] = fractions[0];

	// parameters, [manual, p. 9]
	cfg.ms_n_p1 = t_int(t_real((intval*denom + num) << 7) / t_real(denom) - 512);
	cfg.ms_n_p2 = (num << 7) % denom;
	cfg.ms_n_p3 = denom;
	cfg.eps = eps;


	// pll parameters [manual, p. 15]
	t_real K = cfg.f_P >= 15. ? 925. : 325.;
	if(cfg.f_P < 8.)
		cfg.f_P = 185.;
	t_real Q = cfg.f_V > 2425. ? 1599. : 2132.;
	cfg.k_phi = t_int(std::round(K/Q * cfg.f_V/cfg.f_P * std::pow(2500. / cfg.f_V, 3.)));
	cfg.ms_cal = t_int(std::round(-0.00667 * cfg.f_V + 20.67));

	if(cfg.k_phi < 1 || cfg.k_phi > 127)
		std::cerr << "Error: Invalid k_phi." << std::endl;

	return cfg;
}


int main(int argc, char** argv)
{
	try
	{
		bool show_help = false;
		t_real in_freq = 25.;
		t_real out_freq = 100.;
		bool in_freq_from_xtal = true;

		args::options_description arg_descr("ROM generator arguments");
		arg_descr.add_options()
			("help", args::bool_switch(&show_help), "show help")
			("in_freq,i", args::value<decltype(in_freq)>(&in_freq),
				("input frequency, default: "
					+ std::to_string(in_freq)).c_str())
			("out_freq,o", args::value<decltype(out_freq)>(&out_freq),
				("output frequency, default: "
					+ std::to_string(out_freq)).c_str())
			("in_freq_xtal,x", args::value<bool>(&in_freq_from_xtal),
				("input frequency comes from xtal oscillator, default: "
					+ std::to_string(in_freq_from_xtal)).c_str());

		auto argparser = args::command_line_parser{argc, argv};
		argparser.style(args::command_line_style::default_style);
		argparser.options(arg_descr);

		args::variables_map mapArgs;
		auto parsedArgs = argparser.run();
		args::store(parsedArgs, mapArgs);
		args::notify(mapArgs);

		if(show_help)
		{
			std::cout << arg_descr << std::endl;
			return 0;
		}

		ClockGenCfg cfg = find_clk_gen_cfg(in_freq, out_freq, in_freq_from_xtal);

		std::cout << "f_in    = " << in_freq << " MHz" << std::endl;
		std::cout << "f_out   = " << out_freq << " MHz" << std::endl;
		std::cout << "f_pfd   = " << cfg.f_P << " MHz" << std::endl;
		std::cout << "f_vco   = " << cfg.f_V << " MHz" << std::endl;
		std::cout << "P       = " << cfg.P << std::endl;
		std::cout << "R       = " << cfg.R << std::endl;
		std::cout << std::endl;
		std::cout << "ms_n    = " << cfg.ms_n << std::endl;
		std::cout << "eps     = " << cfg.eps << std::endl;
		std::cout << "ms_n_p1 = " << std::dec << cfg.ms_n_p1
			<< " = 0x" << std::hex << cfg.ms_n_p1 << std::endl;
		std::cout << "ms_n_p2 = " << std::dec << cfg.ms_n_p2
			<< " = 0x" << std::hex << cfg.ms_n_p2 << std::endl;
		std::cout << "ms_n_p3 = " << std::dec << cfg.ms_n_p3
			<< " = 0x" << std::hex << cfg.ms_n_p3 << std::endl;
		std::cout << std::endl;
		std::cout << "k_phi   = " << std::dec << cfg.k_phi
			<< " = 0x" << std::hex << cfg.k_phi << std::endl;
		std::cout << "ms_cal  = " << std::dec << cfg.ms_cal
			<< " = 0x" << std::hex << cfg.ms_cal << std::endl;
	}
	catch(const std::exception& ex)
	{
		std::cerr << "Error: " << ex.what() << std::endl;
		return -1;
	}

	return 0;
}
