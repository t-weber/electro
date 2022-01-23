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


/**
 * send 8 bits to the display
 */
void oled_send_byte(const OLEDInfo* oled, uint8_t data)
{
	oled->i2c_begin(oled->i2c_addr);
	oled->i2c_write(0x00);
	oled->i2c_write(data);
	oled->i2c_end(oled->i2c_addr);
}


/**
 * send a command to the display
 */
void oled_send_command(const OLEDInfo* oled, uint8_t data)
{
	oled_send_byte(oled, 0);
	oled_send_byte(oled, data);
}


/**
 * initialise the display
 */
void oled_init(const OLEDInfo* oled)
{
	oled->delay(20);
 
	oled_onoff(oled, 1, 0);
	oled_contrast(oled, 0xff);
}


/**
 * turn the display on/off
 */
void oled_onoff(const OLEDInfo* oled, bool on, bool inverted)
{
	if(on)
	{
		if(inverted)
			oled_send_command(oled, 0xa7);
		else
			oled_send_command(oled, 0xa6);

		oled_send_command(oled, 0xaf);
		oled_send_command(oled, 0xa4);
	}
	else
	{
		oled_send_command(oled, 0xa5);
		oled_send_command(oled, 0xae);
	}
}


/**
 * set the contrast
 */
extern void oled_contrast(const OLEDInfo* oled, uint8_t contrast)
{
	oled_send_command(oled, 0x81);
	oled_send_byte(oled, contrast);
}
