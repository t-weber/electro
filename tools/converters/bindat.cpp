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
	istr.read(reinterpret_cast<char*>(&json_len), sizeof(json_len));

	// read header
	std::string json_str;
	json_str.resize(json_len);
	istr.read(json_str.data(), json_len);

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
	if(const json::object* hdr_obj = json_hdr.if_object())
	{
		for(const auto& pair : (*hdr_obj))
		{
			if(json::get<0>(pair) == "channel")
				continue;

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

	// get channel infos from header
	if(const json::array *json_chs = json_hdr.at("channel").if_array())
	{
		// iterate channels
		std::size_t ch_idx = 0;
		for(const json::value& _json_ch : (*json_chs))
		{
			const json::object* json_ch = _json_ch.if_object();
			if(!json_ch)
				continue;

			t_real Vscale = 1., Vrate = 1., Hrate = 1.;
			t_data zero = 0;

			for(const auto& pair : (*json_ch))
			{
				std::ostringstream ostrKeyRaw, ostrKey, ostrVal;
				ostrVal.precision(prec);

				ostrKeyRaw << json::get<0>(pair);
				ostrKey << "ch" << ch_idx << "_" << ostrKeyRaw.str();
				ostrVal << json::get<1>(pair);

				// remove "" and ()
				std::string strVal = ostrVal.str();
				if(strVal.length() > 1 && strVal[0] == '\"' && strVal[strVal.length() - 1] == '\"')
					strVal = strVal.substr(1, strVal.length() - 2);
				if(strVal.length() > 1 && strVal[0] == '(' && strVal[strVal.length() - 1] == ')')
					strVal = strVal.substr(1, strVal.length() - 2);

				if(boost::to_lower_copy(ostrKeyRaw.str()) == "vscale")
					Vscale = get_voltage(strVal);
				else if(boost::to_lower_copy(ostrKeyRaw.str()) == "voltage_rate")
					Vrate = get_voltage(strVal);
				else if(boost::to_lower_copy(ostrKeyRaw.str()) == "sample_rate")
					Hrate = get_sample_rate(strVal);  // samples per second
				else if(boost::to_lower_copy(ostrKeyRaw.str()) == "reference_zero")
					std::istringstream{strVal} >> zero;

				data.header.emplace(std::make_pair(ostrKey.str(), strVal));
			}

			data.Vscales.push_back(Vscale);
			data.Vrates.push_back(Vrate);
			data.Hrates.push_back(Hrate);
			data.zeroes.push_back(zero);
			++ch_idx;
		}
	}

	return true;
}


/**
 * load the actual data from the bin file
 */
static bool load_channels(std::istream& istr, Data& data)
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

		for(std::size_t idx = 0; idx < num_dat; ++idx)
		{
			t_data dat_raw = 0;
			if(!istr.read(reinterpret_cast<char*>(&dat_raw), sizeof(dat_raw)))
				break;

			std::size_t cur_channel = data.channels.size();

			// scale data
			t_real dat = static_cast<t_real>(dat_raw - data.zeroes[cur_channel]);
			dat *= data.Vrates[cur_channel] / data.Vscales[cur_channel];

			channel_raw.push_back(dat_raw);
			channel.push_back(dat);
		}

		if(num_dat)
		{
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
		int prec = 8;
		std::string in_file, out_file;

		// parse args
		args::options_description arg_descr("bin data converter arguments");
		arg_descr.add_options()
			("help", args::bool_switch(&show_help), "show help")
			("raw,r", args::bool_switch(&print_raw), "print raw values")
			("prec,p", args::value<decltype(prec)>(&prec), ("precision, default: " + std::to_string(prec)).c_str())
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

		if(!load_channels(ifstr, data))
		{
			std::cerr << "Error: Invalid data." << std::endl;
			return -5;
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
