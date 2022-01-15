/**
 * simple lcd module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * @see https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 */

#ifndef __MY_LCD_H__
#define __MY_LCD_H__

#include "defines.h"


typedef struct _LCDInfo
{
	/* use direct pins or i2c bus */
	bool pin_mode;

	/*------------------------------------------------------------*/
	/* pin mode */
	/*------------------------------------------------------------*/
	/* enable and register select pins */
	int pin_en;
	int pin_rs;

	/* data pins for 4-bit mode */
	int pin_d4;
	int pin_d5;
	int pin_d6;
	int pin_d7;

	/* constants for set or unset pins */
	int pin_set;
	int pin_unset;

	/* (microcontroller's) outout function */
	void (*set_pin)(uint8_t pin, uint8_t state);
	/*------------------------------------------------------------*/

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
} LCDInfo;


/**
 * send 4 bits to the display
 */
extern void lcd_send_nibble(const LCDInfo* lcd, bool rs, uint8_t data);
extern void lcd_send_nibble_pins(const LCDInfo* lcd, bool rs, uint8_t data);
extern void lcd_send_nibble_i2c(const LCDInfo* lcd, bool rs, uint8_t data);


/**
 * send 8 bits to the display
 */
extern void lcd_send_byte(const LCDInfo* lcd, bool rs, uint8_t data);


/**
 * initialise the display
 * @see p. 12 of https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 */
extern void lcd_init(const LCDInfo* lcd);


/**
 * clear the screen
 */
extern void lcd_clear(const LCDInfo* lcd);


/**
 * set the direction of the caret
 */
extern void lcd_set_caret_direction(const LCDInfo* lcd, bool inc, bool shift);


/**
 * caret return
 */
extern void lcd_return(const LCDInfo* lcd);


/**
 * shift display
 */
extern void lcd_shift(const LCDInfo* lcd, bool all, bool right);


/**
 * set display functions
 */
extern void lcd_set_function(const LCDInfo* lcd, bool bits_8, bool two_lines, bool font);


/**
 * turn display and caret on or off
 */
extern void lcd_set_display(const LCDInfo* lcd, bool on, bool caret_line, bool caret_box);


/**
 * set address of display or character ram
 */
extern void lcd_set_address(const LCDInfo* lcd, bool disp, uint8_t addr);


/**
 * write a string to the display
 */
extern void lcd_puts(const LCDInfo* lcd, const t_char* str);


#endif
