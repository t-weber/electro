/**
 * loads oscilloscope binary data
 * @author Tobias Weber
 * @date 29-April-2025
 * @license see 'LICENSE' file
 *
 * g++ -std=c++20 -O2 -Wall -Wextra -Weffc++ -o bindat bindat.cpp -lboost_program_options -lboost_json
 *
 */

#include <vector>
#include <map>
#include <memory>
#include <regex>
#include <limits>
#include <optional>
#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <cstdint>

#include <boost/algorithm/string.hpp>
#include <boost/program_options.hpp>
#include <boost/json.hpp>
namespace args = boost::program_options;
namespace json = boost::json;


using t_offs = std::uint32_t;
using t_data = std::int16_t;
using t_real = double;


/**
 * get numeric value of prefix
 */
static t_real get_prefix(const std::string& str)
{
	t_real prefix{1.};

	if(str == "k" || str == "K")
		prefix = 1e3;
	else if(str == "M")
		prefix = 1e6;
	else if(str == "G" || str == "g")
		prefix = 1e9;
	else if(str == "T" || str == "t")
		prefix = 1e12;
	else if(str == "m")
		prefix = 1e-3;
	else if(str == "u" || str == "U")
		prefix = 1e-6;
	else if(str == "n" || str == "N")
		prefix = 1e-9;
	else if(str == "f" || str == "F")
		prefix = 1e-12;
	else
		std::cerr << "Error: Unknown prefix \"" << str << "\"." << std::endl;

	return prefix;
}


/**
 * get number of volts
 */
static t_real get_voltage(const std::string& str)
{
	t_real val{};

	static const std::regex regex{"([0-9]+(\\.[0-9]*)?([Ee][+-]?[0-9]*)?)[ \\t]*([munfkMGT])[Vv]"};
	std::smatch smatch;
	if(std::regex_match(str, smatch, regex))
	{
		std::istringstream{smatch.str(1)} >> val;
		val *= get_prefix(smatch.str(4));
	}

	return val;
}


/**
 * get number of samples per second
 */
static t_real get_sample_rate(const std::string& str)
{
	t_real val{1.};

	static const std::regex regex{"([0-9]+(\\.[0-9]*)?([Ee][+-]?[0-9]*)?)[ \\t]*([munfkKMGT])S/s"};
	std::smatch smatch;
	if(std::regex_match(str, smatch, regex))
	{
		std::istringstream{smatch.str(1)} >> val;
		val *= get_prefix(smatch.str(4));
	}

	return val;
}


/**
 * smoothing of data points
 * see: https://en.wikipedia.org/wiki/Laplacian_smoothing
 */
template<class t_cont>
t_cont smooth_data(const t_cont& vec, std::size_t N = 1)
requires requires(t_cont cont)
{
	typename t_cont::value_type;
	cont.size();
	cont[0] = cont[1];
}
{
	if(N <= 0)
		return vec;

	using t_val = typename t_cont::value_type;

	t_cont smoothed = vec;

	for(std::size_t i = 0; i < vec.size(); ++i)
	{
		t_val elem{};
		t_val num{};

		for(std::ptrdiff_t j = -static_cast<std::ptrdiff_t>(N); j <= static_cast<std::ptrdiff_t>(N); ++j)
		{
			if(static_cast<std::ptrdiff_t>(i) + j < 0)
				continue;

			std::size_t idx = i + j;
			if(idx >= vec.size())
				continue;

			elem += vec[i + j];
			num += 1;
		}

		smoothed[i] = elem / num;
	}

	return smoothed;
}


/**
 * binary data
 */
struct Data
{
	std::map<std::string, std::string> header;

	std::vector<t_real> Vscales, Vrates, Hrates;
	std::vector<t_data> zeroes;

	std::vector<std::vector<t_data>> channels_raw;
	std::vector<std::vector<t_real>> channels;
};


static bool load_header(std::istream& istr, Data& data, int prec = 8)
{
	// get header length
	t_offs json_len = 0;
	if(!istr.read(reinterpret_cast<char*>(&json_len), sizeof(json_len)))
	{
		std::cerr << "Error: Cannot read header size." << std::endl;
		return false;
	}

	// read header
	std::string json_str;
	json_str.resize(json_len);
	if(!istr.read(json_str.data(), json_len))
	{
		std::cerr << "Error: Cannot read header." << std::endl;
		return false;
	}

	//json_str = boost::to_lower_copy(json_str);

	// parse header json
	boost::system::error_code json_err;
	json::parse_options json_opts
	{
		.numbers = json::number_precision::precise,
		.allow_trailing_commas = true,
	};
	json::value json_hdr = json::parse(json_str, json_err, {}, json_opts);
	if(json_err)
	{
		std::cerr << "Error: " << json_err.message() << std::endl;
		return false;
	}


	// get general infos from header
	std::optional<json::value> _json_chs;
	if(const json::object* hdr_obj = json_hdr.if_object())
	{
		for(const auto& pair : (*hdr_obj))
		{
			if(boost::iequals(json::get<0>(pair), "channel"))
			{
				_json_chs = json::get<1>(pair);
				continue;
			}

			std::ostringstream ostrKey, ostrVal;
			ostrVal.precision(prec);

			ostrKey << "info_" << json::get<0>(pair);
			ostrVal << json::get<1>(pair);

			// remove ""
			std::string strVal = ostrVal.str();
			if(strVal.length() > 1 && strVal[0] == '\"' && strVal[strVal.length() - 1] == '\"')
				strVal = strVal.substr(1, strVal.length() - 2);

			data.header.emplace(std::make_pair(ostrKey.str(), strVal));
		}
	}

	if(!_json_chs)
	{
		std::cerr << "Error: Could not find channel infos." << std::endl;
		return false;
	}

	// get channel infos from header
	//const json::array *json_chs = json_hdr.at("channel").if_array();
	const json::array *json_chs = _json_chs->if_array();
	if(!json_chs)
	{
		std::cerr << "Error: Unknown channel info format." << std::endl;
		return false;
	}

	// iterate channels
	std::size_t ch_idx = 0;
	for(const json::value& _json_ch : (*json_chs))
	{
		const json::object* json_ch = _json_ch.if_object();
		if(!json_ch)
			continue;

		t_real Vscale = 1., Vrate = 1., Hrate = 1.;
		t_data zero = 0;

		// iterate channel key-value pairs
		for(const auto& pair : (*json_ch))
		{
			std::ostringstream ostrKey, ostrVal;
			ostrVal.precision(prec);

			std::string strKeyRaw = json::get<0>(pair);
			ostrKey << "ch" << ch_idx << "_" << strKeyRaw;
			ostrVal << json::get<1>(pair);
			std::string strVal = ostrVal.str();

			// remove "" and ()
			if(strVal.length() > 1 && strVal[0] == '\"' && strVal[strVal.length() - 1] == '\"')
				strVal = strVal.substr(1, strVal.length() - 2);
			if(strVal.length() > 1 && strVal[0] == '(' && strVal[strVal.length() - 1] == ')')
				strVal = strVal.substr(1, strVal.length() - 2);

			if(boost::iequals(strKeyRaw, "vscale"))
				Vscale = get_voltage(strVal);
			else if(boost::iequals(strKeyRaw, "voltage_rate"))
				Vrate = get_voltage(strVal);
			else if(boost::iequals(strKeyRaw, "sample_rate"))
				Hrate = get_sample_rate(strVal);  // samples per second
			else if(boost::iequals(strKeyRaw, "reference_zero"))
				std::istringstream{strVal} >> zero;

			data.header.emplace(std::make_pair(ostrKey.str(), strVal));
		}

		data.Vscales.push_back(Vscale);
		data.Vrates.push_back(Vrate);
		data.Hrates.push_back(Hrate);
		data.zeroes.push_back(zero);
		++ch_idx;
	}

	return true;
}


/**
 * load the actual data from the bin file
 */
static bool load_channels(std::istream& istr, Data& data,
	int shift_data = 0, int prec = 8)
{
	while(true)
	{
		// read number of data points
		t_offs num_dat = 0;
		if(!istr.read(reinterpret_cast<char*>(&num_dat), sizeof(num_dat)))
			break;
		num_dat /= sizeof(t_data);

		std::vector<t_data> channel_raw;
		std::vector<t_real> channel;
		channel.reserve(num_dat);

		t_real min = std::numeric_limits<t_real>::max();
		t_real max = -min;
		t_real mean{};

		for(std::size_t idx = 0; idx < num_dat; ++idx)
		{
			t_data dat_raw = 0;
			if(!istr.read(reinterpret_cast<char*>(&dat_raw), sizeof(dat_raw)))
				break;

			std::size_t cur_channel = data.channels.size();

			// scale data
			t_real dat = static_cast<t_real>(dat_raw - data.zeroes[cur_channel]);
			dat *= data.Vrates[cur_channel] / data.Vscales[cur_channel];

			min = std::min(min, dat);
			max = std::max(max, dat);
			mean += dat;

			channel_raw.push_back(dat_raw);
			channel.push_back(dat);
		}

		if(num_dat > 0)
		{
			const std::size_t ch_idx = data.channels.size();
			mean /= static_cast<t_real>(num_dat);

			t_real stddev{};
			for(t_real val : channel)
				stddev += (val - mean)*(val - mean);
			stddev /= static_cast<t_real>(num_dat);
			stddev = std::sqrt(stddev);

			if(shift_data == 1)       // shift to min
			{
				for(t_real& val : channel)
					val -= min;
			}
			else if(shift_data == 2)  // shift to max
			{
				for(t_real& val : channel)
					val -= max;
			}
			else if(shift_data == 3)  // shift to mean
			{
				for(t_real& val : channel)
					val -= mean;
			}

			// insert header infos
			std::ostringstream ostrMin, ostrMax, ostrMean, ostrStdDev, ostrRange;
			for(std::ostringstream* ostr : {&ostrMin, &ostrMax, &ostrMean, &ostrStdDev, &ostrRange})
				ostr->precision(prec);
			ostrMin << min;
			ostrMax << max;
			ostrMean << mean;
			ostrStdDev << stddev;
			ostrRange << max - min;

			data.header.emplace(std::make_pair(
				(std::ostringstream{} << "ch" << ch_idx << "_min").str(), ostrMin.str()));
			data.header.emplace(std::make_pair(
				(std::ostringstream{} << "ch" << ch_idx << "_max").str(), ostrMax.str()));
			data.header.emplace(std::make_pair(
				(std::ostringstream{} << "ch" << ch_idx << "_mean").str(), ostrMean.str()));
			data.header.emplace(std::make_pair(
				(std::ostringstream{} << "ch" << ch_idx << "_stddev").str(), ostrStdDev.str()));
			data.header.emplace(std::make_pair(
				(std::ostringstream{} << "ch" << ch_idx << "_range").str(), ostrRange.str()));

			// insert channel data vectors
			data.channels_raw.emplace_back(std::move(channel_raw));
			data.channels.emplace_back(std::move(channel));
		}
	}

	if(data.channels.size() == 0)
	{
		std::cerr << "Error: No data could be read." << std::endl;
		return false;
	}

	return true;
}


/**
 * write a text data file
 */
static bool write_text_file(const std::string& out_file, const Data& data,
	bool print_raw = false, int prec = 8)
{
	std::shared_ptr<std::ofstream> ofstr;
	std::ostream *ostr = &std::cout;
	if(out_file != "")
	{
		ofstr = std::make_shared<std::ofstream>(out_file);
		if(!ofstr || !*ofstr)
		{
			std::cerr << "Error: Cannot open \"" << out_file << "\"." << std::endl;
			return false;
		}
		ostr = ofstr.get();
	}

	// write header
	ostr->precision(prec);
	(*ostr) << "#\n";
	for(const auto& [key, val] : data.header)
		(*ostr) << "# " << key << " = " << val << "\n";
	(*ostr) << "#\n";

	// write data columns
	int w = prec * 1.75;
	(*ostr) << std::left << std::setw(w) << "# idx" << " ";
	(*ostr) << std::left << std::setw(w) << "t" << " ";
	for(std::size_t ch = 0; ch < data.channels.size(); ++ch)
		(*ostr) << "ch" << std::left << std::setw(w-2) << ch << " ";

	if(print_raw)
	{
		for(std::size_t ch = 0; ch < data.channels.size(); ++ch)
			(*ostr) << "raw_ch" << std::left << std::setw(w-6) << ch << " ";
	}

	(*ostr) << "\n";

	for(std::size_t idx = 0; idx < data.channels[0].size(); ++idx)
	{
		t_real t = idx / data.Hrates[0];

		(*ostr) << std::left << std::setw(w) << idx << " ";
		(*ostr) << std::left << std::setw(w) << t << " ";

		for(std::size_t ch = 0; ch < data.channels.size(); ++ch)
			(*ostr) << std::left << std::setw(w) << data.channels[ch][idx] << " ";

		if(print_raw)
		{
			for(std::size_t ch = 0; ch < data.channels_raw.size(); ++ch)
				(*ostr) << std::left << std::setw(w) << data.channels_raw[ch][idx] << " ";
		}

		(*ostr) << "\n";
	}
	ostr->flush();

	return true;
}


int main(int argc, char** argv)
{
	try
	{
		bool show_help = false;
		bool print_raw = false;
		int shift_data = 0;
		std::size_t laplace_smooth = 0;
		int prec = 8;
		std::string in_file, out_file;

		// parse args
		args::options_description arg_descr("bin data converter arguments");
		arg_descr.add_options()
			("help", args::bool_switch(&show_help), "show help")
			("raw,r", args::bool_switch(&print_raw), "print raw values")
			("prec,p", args::value<decltype(prec)>(&prec), ("precision, default: " + std::to_string(prec)).c_str())
			("shift,s", args::value<decltype(shift_data)>(&shift_data), ("shift data (0: off, 1: to min, 2: to max, 3: to mean), default: " + std::to_string(shift_data)).c_str())
			("laplace,l", args::value<decltype(laplace_smooth)>(&laplace_smooth), ("laplacian smoothing, default: " + std::to_string(laplace_smooth)).c_str())
			("input,i", args::value<decltype(in_file)>(&in_file), "input binary data")
			("output,o", args::value<decltype(out_file)>(&out_file), "output text data");

		args::positional_options_description posarg_descr;
		posarg_descr.add("input", -1);

		auto argparser = args::command_line_parser{argc, argv};
		argparser.style(args::command_line_style::default_style);
		argparser.options(arg_descr);
		argparser.positional(posarg_descr);

		args::variables_map mapArgs;
		auto parsedArgs = argparser.run();
		args::store(parsedArgs, mapArgs);
		args::notify(mapArgs);

		if(show_help || in_file == "")
		{
			std::cout << arg_descr << std::endl;
			return 0;
		}


		// load binary data
		std::ifstream ifstr{in_file};
		if(!ifstr)
		{
			std::cerr << "Error: Cannot open \"" << in_file << "\"." << std::endl;
			return -2;
		}

		// check file magic
		char magic[6];
		ifstr.read(magic, sizeof(magic));
		if(std::string_view(magic, magic + 6) != "SPBXDS")
		{
			std::cerr << "Error: Unknown file format." << std::endl;
			return -3;
		}

		// read the bin data file
		Data data{};

		if(!load_header(ifstr, data, prec))
		{
			std::cerr << "Error: Invalid header." << std::endl;
			return -4;
		}

		if(!load_channels(ifstr, data, shift_data, prec))
		{
			std::cerr << "Error: Invalid data." << std::endl;
			return -5;
		}


		// data reduction
		if(laplace_smooth)
		{
			for(std::size_t ch_idx = 0; ch_idx < data.channels.size(); ++ch_idx)
				data.channels[ch_idx] = smooth_data(data.channels[ch_idx], laplace_smooth);
		}


		// write a text data file
		if(!write_text_file(out_file, data, print_raw, prec))
		{
			std::cerr << "Error: Cannot write output file." << std::endl;
			return -6;
		}
	}
	catch(const std::exception& ex)
	{
		std::cerr << "Error: " << ex.what() << std::endl;
		return -1;
	}

	return 0;
}
