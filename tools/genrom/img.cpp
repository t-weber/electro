/**
 * reads an image
 * @author Tobias Weber
 * @date 4-Feb-2024
 * @license see 'LICENSE' file
 *
 * References:
 *  * https://github.com/boostorg/gil/tree/develop/example
 *
 */

#include "img.h"

#include <cstdint>

#include <boost/gil/image.hpp>
#include <boost/gil/extension/io/jpeg.hpp>
#include <boost/gil/extension/io/png.hpp>
namespace gil = boost::gil;

using t_image = gil::rgb8_image_t;


/**
 * read in an image
 */
extern std::tuple<std::size_t, std::size_t, std::size_t, t_words>
read_img(t_image& img)
{
	int bits = 8;  // per channel
	auto view = gil::view(img);

	const auto w = img.height();
	const auto h = img.height();
	const auto ch = view.num_channels();

	t_words data;
	data.reserve(w * h);

	for(std::remove_const_t<decltype(h)> y = 0; y < h; ++y)
	{
		for(auto row = view.row_begin(y); row != view.row_end(y); ++row)
		{
			std::uint8_t r = static_cast<std::uint8_t>((*row)[0]);
			std::uint8_t g = static_cast<std::uint8_t>((*row)[1]);
			std::uint8_t b = static_cast<std::uint8_t>((*row)[2]);

			t_word dat(bits*3, (r << (bits*2)) | (g << bits) | b);
			data.emplace_back(std::move(dat));
		}
	}

	return std::make_tuple(w, h, ch, std::move(data));
}


/**
 * read in a jpg image
 */
extern std::tuple<std::size_t, std::size_t, std::size_t, t_words>
read_jpg(const std::filesystem::path& path)
{
	t_image img;
	gil::read_image(path.string(), img,
		gil::image_read_settings<gil::jpeg_tag>{});

	return read_img(img);
}


/**
 * read in a png image
 */
extern std::tuple<std::size_t, std::size_t, std::size_t, t_words>
read_png(const std::filesystem::path& path)
{
	t_image img;
	gil::read_image(path.string(), img,
		gil::image_read_settings<gil::png_tag>{});

	return read_img(img);
}
