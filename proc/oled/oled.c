/**
 * oled module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * @see https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 * @see https://www.instructables.com/Getting-Started-With-OLED-Displays/
 */

#include "oled.h"
#include <stdlib.h>


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

	oled->delay(20);
	oled_onoff(oled, 0, 0, 1);

	oled_address_mode(oled, 0);
	oled_direction(oled, 1, 0);
	oled_offset(oled, 0, 0);

	oled_clear(oled, 0);
	oled_update(oled);

	oled_contrast(oled, 0xff);
	oled_onoff(oled, 1, 0, 1);
}


/**
 * initialise the display
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
	uint8_t h_offs = (uint8_t)x;
	uint8_t v_offs = (uint8_t)(y / oled->pixels_per_page);
	uint8_t v_bit = (uint8_t)(y % oled->pixels_per_page);
	uint16_t lin_offs = v_offs*oled->width + h_offs;

	if(lin_offs >= oled->width*oled->pages)
		return;

	uint8_t val = oled->framebuffer[lin_offs];
	if(set)
		val |= 1 << (/*8-*/v_bit);
	else
		val &= ~(1 << (/*8-*/v_bit));
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
