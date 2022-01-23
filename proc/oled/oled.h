/**
 * oled module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * @see https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 * @see https://www.instructables.com/Getting-Started-With-OLED-Displays/
 */

#ifndef __MY_OLED_H__
#define __MY_OLED_H__

#include "defines.h"


typedef struct _OLEDInfo
{
	uint16_t width;
	uint16_t height;

	/*------------------------------------------------------------*/
	/* i2c mode */
	/*------------------------------------------------------------*/
	uint8_t i2c_addr;

	void (*i2c_write)(uint8_t data);
	void (*i2c_begin)(uint8_t addr);
	void (*i2c_end)(uint8_t addr);
	/*------------------------------------------------------------*/

	/* (microcontroller's) delay function */
	void (*delay)(uint32_t millisecs);
} OLEDInfo;


/**
 * send 8 bits to the display
 */
extern void oled_send_byte(const OLEDInfo* oled, uint8_t data);


/**
 * send a command to the display
 */
extern void oled_send_command(const OLEDInfo* oled, uint8_t data);


/**
 * initialise the display
 */
extern void oled_init(const OLEDInfo* oled);


/**
 * turn the display on/off
 */
extern void oled_onoff(const OLEDInfo* oled, bool on, bool inverted);


/**
 * set the contrast
 */
extern void oled_contrast(const OLEDInfo* oled, uint8_t contrast);


#endif
