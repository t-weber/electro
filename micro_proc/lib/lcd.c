/**
 * simple lcd module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * @see https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 */

#include "lcd.h"


/**
 * send 4 bits to the display via direct pin connections
 */
void lcd_send_nibble_pins(const LCDInfo* lcd, bool rs, uint8_t data)
{
	lcd->set_pin(lcd->pin_en, lcd->pin_unset);
	lcd->set_pin(lcd->pin_rs, rs ? lcd->pin_set : lcd->pin_unset);
	lcd->set_pin(lcd->pin_d4, (data & 1) ? lcd->pin_set : lcd->pin_unset);
	lcd->set_pin(lcd->pin_d5, ((data>>1) & 1) ? lcd->pin_set : lcd->pin_unset);
	lcd->set_pin(lcd->pin_d6, ((data>>2) & 1) ? lcd->pin_set : lcd->pin_unset);
	lcd->set_pin(lcd->pin_d7, ((data>>3) & 1) ? lcd->pin_set : lcd->pin_unset);
	lcd->set_pin(lcd->pin_en, lcd->pin_set);
	lcd->delay(1);
	lcd->set_pin(lcd->pin_en, lcd->pin_unset);
}


/**
 * send 4 bits to the display via the 2-wire bus
 */
void lcd_send_nibble_wire(const LCDInfo* lcd, bool rs, uint8_t data)
{
	uint8_t pin_en = 0b0100;
	uint8_t pin_rs = 0b0001;
	uint8_t pin_led = 0b1000;

	data <<= 4;
	if(rs)
		data |= pin_rs;
	data |= pin_led;

	lcd->wire_begin(lcd->wire_addr);
	lcd->wire_write(data | pin_en);
	lcd->wire_end(lcd->wire_addr);

	lcd->delay(1);
	lcd->wire_begin(lcd->wire_addr);
	lcd->wire_write(data);
	lcd->wire_end(lcd->wire_addr);
}


/**
 * send 4 bits to the display
 */
void lcd_send_nibble(const LCDInfo* lcd, bool rs, uint8_t data)
{
	if(lcd->pin_mode)
		lcd_send_nibble_pins(lcd, rs, data);
	else
		lcd_send_nibble_wire(lcd, rs, data);
}


/**
 * send 8 bits to the display
 */
void lcd_send_byte(const LCDInfo* lcd, bool rs, uint8_t data)
{
	lcd_send_nibble(lcd, rs, (data&0xf0)>>4);
	lcd_send_nibble(lcd, rs, data&0x0f);
}


/**
 * initialise the display
 * @see p. 12 of https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 */
void lcd_init(const LCDInfo* lcd)
{
	lcd->delay(20);
	lcd_send_nibble(lcd, 0, 0b0011);
	lcd->delay(5);
	lcd_send_nibble(lcd, 0, 0b0011);
	lcd->delay(1);
	lcd_send_nibble(lcd, 0, 0b0011);
	lcd_send_nibble(lcd, 0, 0b0010);
}


/**
 * clear the screen
 */
void lcd_clear(const LCDInfo* lcd)
{
	lcd_send_byte(lcd, 0, 0b00000001);
	lcd->delay(2);
}


/**
 * set the direction of the caret
 */
void lcd_set_caret_direction(const LCDInfo* lcd, bool inc, bool shift)
{
	uint8_t byte = 0b00000100;
	if(inc)
		byte |= 1<<1;
	if(shift)
		byte |= 1;
	lcd_send_byte(lcd, 0, byte);
}


/**
 * caret return
 */
void lcd_return(const LCDInfo* lcd)
{
	lcd_send_byte(lcd, 0, 0b00000010);
	lcd->delay(2);
}


/**
 * shift display
 */
void lcd_shift(const LCDInfo* lcd, bool all, bool right)
{
	uint8_t byte = 0b00010000;
	if(all) /* shift all or just caret? */
		byte |= 1<<3;
	if(right)
		byte |= 1<<2;
	lcd_send_byte(lcd, 0, byte);
}


/**
 * set display functions
 */
void lcd_set_function(const LCDInfo* lcd, bool bits_8, bool two_lines, bool font)
{
	uint8_t byte = 0b00100000;
	if(bits_8)
		byte |= 1<<4;
	if(two_lines)
		byte |= 1<<3;
	if(font)
		byte |= 1<<2;
	lcd_send_byte(lcd, 0, byte);
}


/**
 * turn display and caret on or off
 */
void lcd_set_display(const LCDInfo* lcd, bool on, bool caret_line, bool caret_box)
{
	uint8_t byte = 0b00001000;
	if(on)
		byte |= 1<<2;
	if(caret_line)
		byte |= 1<<1;
	if(caret_box)
		byte |= 1;
	lcd_send_byte(lcd, 0, byte);
}


/**
 * set address of display or character ram
 */
void lcd_set_address(const LCDInfo* lcd, bool disp, uint8_t addr)
{
	uint8_t byte = 0;

	if(disp)
	{
		byte = 0b10000000;
		byte |= addr & 0b01111111;
	}
	else
	{
		byte = 0b01000000;
		byte |= addr & 0b00111111;
	}

	lcd_send_byte(lcd, 0, byte);
}


/**
 * write a string to the display
 */
void lcd_puts(const LCDInfo* lcd, const t_char* str)
{
	const t_char* iter = str;
	while(*iter)
	{
		lcd_send_byte(lcd, 1, (uint8_t)*iter);
		++iter;
	}
}
