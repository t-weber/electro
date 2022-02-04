/**
 * oled module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * @see https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 * @see https://www.instructables.com/Getting-Started-With-OLED-Displays/
 */

#include <stdlib.h>

#include "oled.h"

#if __has_include("characters.c")
	#include "characters.c"
	#define _HAS_FONT_
#else
	#pragma message("Please create the font character map using tools/create_font.cpp!")
#endif


/**
 * send 8 bits to the display
 */
void oled_send_byte(const OLEDInfo* oled, bool is_command, uint8_t data)
{
	oled->i2c_begin(oled->i2c_addr);
	if(is_command)
		oled->i2c_write(0x80);
	else
		oled->i2c_write(0xc0);

	oled->i2c_write(data);
	oled->i2c_end(oled->i2c_addr);
}


/**
 * send 16 bits to the display
 */
void oled_send_2bytes(const OLEDInfo* oled, bool is_command,
	uint8_t data1, uint8_t data2)
{
	oled->i2c_begin(oled->i2c_addr);
	if(is_command)
		oled->i2c_write(0x00);
	else
		oled->i2c_write(0x40);

	oled->i2c_write(data1);
	oled->i2c_write(data2);
	oled->i2c_end(oled->i2c_addr);
}


/**
 * send an array of data to the display
 */
void oled_send_nbytes(const OLEDInfo* oled, bool is_command,
	const uint8_t *data, t_size len)
{
	oled->i2c_begin(oled->i2c_addr);
	if(is_command)
		oled->i2c_write(0x00);
	else
		oled->i2c_write(0x40);

	for(t_size i=0; i<len; ++i)
		oled->i2c_write(data[i]);
	oled->i2c_end(oled->i2c_addr);
}


/**
 * initialise the display
 */
void oled_init(OLEDInfo* oled)
{
	oled->pixels_per_page = 8;
	oled->pages = oled->height / oled->pixels_per_page;
	oled->framebuffer = (uint8_t*)malloc(oled->width * oled->pages);

	oled_set_cursor(oled, 0, 0);

	oled->delay(20);
	oled_onoff(oled, 0, 0, 1);

	oled_clock(oled, 0, 15, 2, 2);
	oled_mux(oled, oled->height-1);

	oled_address_mode(oled, 0);
	oled_direction(oled, 1, 0);
	oled_offset(oled, 0, 0);

	oled_clear(oled, 0);
	oled_update(oled);

	oled_contrast(oled, 0xff);
	oled_onoff(oled, 1, 0, 1);
	//oled->delay(20);
}


/**
 * deinitialise the display
 */
void oled_deinit(OLEDInfo* oled)
{
	oled_onoff(oled, 0, 0, 1);

	if(oled->framebuffer)
	{
		free(oled->framebuffer);
		oled->framebuffer = 0;
	}
}


/**
 * turn the display on/off
 */
void oled_onoff(const OLEDInfo* oled,
	bool on, bool inverted, bool capacitor)
{
	if(on)
	{
		if(inverted)
			oled_send_byte(oled, 1, 0xa7);
		else
			oled_send_byte(oled, 1, 0xa6);

		if(capacitor)
			oled_send_2bytes(oled, 1, 0x8d, 0b0100);
		else
			oled_send_2bytes(oled, 1, 0x8d, 0b0000);

		oled_send_byte(oled, 1, 0xaf);
		oled_send_byte(oled, 1, 0xa4);
	}
	else
	{
		oled_send_byte(oled, 1, 0xa5);
		oled_send_byte(oled, 1, 0xae);
	}
}


/**
 * set the address mode
 * mode 0: page-by-page, 1: column-by-column, 2: no page increment
 */
void oled_address_mode(OLEDInfo* oled, uint8_t mode)
{
	oled->mode = mode;
	oled_send_2bytes(oled, 1, 0x20, mode);
}


/**
 * set the output direction
 */
void oled_direction(const OLEDInfo* oled,
	bool h_inverted, bool v_inverted)
{
	if(h_inverted)
		oled_send_byte(oled, 1, 0xa1);
	else
		oled_send_byte(oled, 1, 0xa0);

	if(v_inverted)
		oled_send_byte(oled, 1, 0xc0);
	else
		oled_send_byte(oled, 1, 0xc8);
}


/**
 * set the horizontal and vertical offset
 */
void oled_offset(const OLEDInfo* oled, uint8_t h_offs, uint8_t v_offs)
{
	oled_send_byte(oled, 1, 0b01000000 | h_offs);
	oled_send_2bytes(oled, 1, 0xd3, v_offs);
}


/**
 * set the contrast
 */
void oled_contrast(const OLEDInfo* oled, uint8_t contrast)
{
	oled_send_2bytes(oled, 1, 0x81, contrast);
}


/**
 * set the clock (divider is assumed +1)
 */
void oled_clock(const OLEDInfo* oled,
	uint8_t divider, uint8_t freq,
	uint8_t pixel_unset_time, uint8_t pixel_set_time)
{
	uint8_t data = (freq & 0x0f) << 4;;
	data |= divider & 0x0f;
	oled_send_2bytes(oled, 1, 0xd5, data);

	data = (pixel_set_time & 0x0f) << 4;;
	data |= pixel_unset_time & 0x0f;
	oled_send_2bytes(oled, 1, 0xd9, data);
}


/**
 * set voltage levels
 */
void oled_voltage(const OLEDInfo* oled, uint8_t unselect_level)
{
	oled_send_2bytes(oled, 1, 0xdb, (unselect_level & 0b0111) << 4);
}


/**
 * pin settings
 */
void oled_pins(const OLEDInfo* oled, bool alternate, bool remap)
{
	uint8_t data = 0;

	if(alternate)
		data |= 1 << 4;
	if(remap)
		data |= 1 << 5;

	oled_send_2bytes(oled, 1, 0xdb, data);
}


/**
 * multiplexer settings
 */
void oled_mux(const OLEDInfo* oled, uint8_t num)
{
	oled_send_2bytes(oled, 1, 0xa8, num);
}


/**
 * set the column and page addresses
 */
void oled_address(const OLEDInfo* oled,
	uint8_t col_start, uint8_t col_end, uint8_t page_start, uint8_t page_end)
{
	if(oled->mode == 0 || oled->mode == 1)
	{
		uint8_t h_cmd[] = {0x21, col_start, col_end};
		oled_send_nbytes(oled, 1, h_cmd, sizeof(h_cmd));

		uint8_t v_cmd[] = {0x22, page_start, page_end};
		oled_send_nbytes(oled, 1, v_cmd, sizeof(v_cmd));
	}
	else if(oled->mode == 2)
	{
		oled_send_byte(oled, 1, col_start & 0x0f);
		oled_send_byte(oled, 1, 0b00010000 | ((col_start & 0xf0) >> 4));

		oled_send_byte(oled, 1, 0b10110000 | page_start);
	}
}


/**
 * settings for horizontal scrolling
 */
void oled_scroll_setup_h(const OLEDInfo* oled, bool left,
	uint8_t page_start, uint8_t page_end, uint8_t speed)
{
	uint8_t cmd = 0b00100110;
	if(left)
		cmd |= 1;

	uint8_t data[] =
	{
		cmd, 0x00,
		page_start,
		speed,
		page_end,
		0x00, 0xff
	};

	oled_send_nbytes(oled, 1, data, sizeof(data));
}


/**
 * settings for horizontal/vertical scrolling
 */
void oled_scroll_setup_hv(const OLEDInfo* oled, bool left,
	uint8_t page_start, uint8_t page_end, uint8_t speed, uint8_t v_offs)
{
	uint8_t cmd = 0b00101000;
	if(left)
		cmd |= 0b10;
	else
		cmd |= 0b01;

	uint8_t data[] =
	{
		cmd, 0x00,
		page_start,
		speed,
		page_end,
		v_offs
	};

	oled_send_nbytes(oled, 1, data, sizeof(data));
}


/**
 * scroll area
 */
void oled_scroll_setup_area(const OLEDInfo* oled,
	uint8_t row_start, uint8_t num_rows)
{
	uint8_t data[] = { 0xa3, row_start, num_rows };
	oled_send_nbytes(oled, 1, data, sizeof(data));
}


/**
 * enable/disable scrolling
 */
void oled_scroll(const OLEDInfo* oled, bool enable)
{
	if(enable)
		oled_send_byte(oled, 1, 0x2f);
	else
		oled_send_byte(oled, 1, 0x2e);
}


/**
 * clear the screen
 */
void oled_clear(const OLEDInfo* oled, uint8_t clear_val)
{
	for(uint16_t i=0; i<oled->width*oled->pages; ++i)
		oled->framebuffer[i] = clear_val;
}


/**
 * draw a pixel
 */
void oled_pixel(const OLEDInfo* oled, uint16_t x, uint16_t y, bool set)
{
	if(x >= oled->width || y >= oled->height)
		return;
	//x %= oled->width;
	//y %= oled->height;

	uint8_t h_offs = (uint8_t)x;
	uint8_t v_offs = (uint8_t)(y / oled->pixels_per_page);
	uint8_t v_bit = (uint8_t)(y % oled->pixels_per_page);
	uint16_t lin_offs = v_offs*oled->width + h_offs;

	if(lin_offs >= oled->width*oled->pages)
		return;

	uint8_t val = oled->framebuffer[lin_offs];
	if(set)
		val |= 1 << v_bit;
	else
		val &= ~(1 << v_bit);
	oled->framebuffer[lin_offs] = val;
}


/**
 * draw the framebuffer
 */
void oled_update(const OLEDInfo* oled)
{
	oled_address(oled, 0, oled->width-1, 0, oled->pages-1);

	for(uint16_t i=0; i<oled->width*oled->pages; ++i)
		oled_send_byte(oled, 0, oled->framebuffer[i]);
}


/**
 * write a char to the display
 */
void oled_putch(OLEDInfo* oled, t_char ch)
{
#ifdef _HAS_FONT_
	// draw character
	const uint16_t ch_idx = (uint16_t)ch - g_characters_first;

	for(uint16_t y=0; y<g_characters_height; ++y)
	{
		uint8_t thebyte = pgm_read_byte(g_characters[ch_idx] + y);

		for(uint16_t x=0; x<g_characters_width; ++x)
		{
			bool thebit = ((thebyte & (1 << (7-x))) != 0);
			if(thebit)
				oled_pixel(oled, oled->cur_x+x, oled->cur_y+y, thebit);
		}
	}

	// advance cursor position
	oled->cur_x += g_characters_width;

	// new line?
	if(oled->cur_x >= oled->width)
	{
		oled->cur_x = 0;
		oled->cur_y += g_characters_height;
	}

	// wrap back to first line?
	if(oled->cur_y >= oled->height)
	{
		oled->cur_y = 0;
	}
#endif
}


/**
 * write a string to the display
 */
void oled_puts(OLEDInfo* oled, const t_char* str)
{
	const t_char* iter = str;
	while(*iter)
	{
		oled_putch(oled, *iter);
		++iter;
	}
}


/**
 * set the cursor position
 */
void oled_set_cursor(OLEDInfo* oled, uint16_t x, uint16_t y)
{
	oled->cur_x = x;
	oled->cur_y = y;
}
