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

	uint16_t pages;
	uint8_t pixels_per_page;

	uint8_t mode;
	uint8_t* framebuffer;

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
extern void oled_send_byte(const OLEDInfo* oled, bool is_command, uint8_t data);


/**
 * send 16 bits to the display
 */
extern void oled_send_2bytes(const OLEDInfo* oled, bool is_command,
	uint8_t data1, uint8_t data2);


/**
 * send an array of data to the display
 */
extern void oled_send_nbytes(const OLEDInfo* oled, bool is_command,
	const uint8_t *data, t_size len);


/**
 * initialise the display
 */
extern void oled_init(OLEDInfo* oled);


/**
 * initialise the display
 */
extern void oled_deinit(OLEDInfo* oled);


/**
 * turn the display on/off
 */
extern void oled_onoff(const OLEDInfo* oled,
	bool on, bool inverted, bool capacitor);


/**
 * set the contrast
 */
extern void oled_contrast(const OLEDInfo* oled, uint8_t contrast);


/**
 * set the clock
 */
extern void oled_clock(const OLEDInfo* oled,
	uint8_t divider, uint8_t freq,
	uint8_t pixel_unset_time, uint8_t pixel_set_time);


/**
 * set voltage levels
 */
extern void oled_voltage(const OLEDInfo* oled, uint8_t unselect_level);


/**
 * pin settings
 */
extern void oled_pins(const OLEDInfo* oled, bool alternate,  bool remap);


/**
 * multiplexer settings
 */
extern void oled_mux(const OLEDInfo* oled, uint8_t num);


/**
 * set the address mode
 * mode 0: page-by-page, 1: column-by-column, 2: no page increment
 */
extern void oled_address_mode(OLEDInfo* oled, uint8_t mode);


/**
 * set the output direction
 */
extern void oled_direction(const OLEDInfo* oled, bool h_inverted, bool v_inverted);


/**
 * set the horizontal and vertical offset
 */
extern void oled_offset(const OLEDInfo* oled, uint8_t h_offs, uint8_t v_offs);


/**
 * set the column and page addresses
 */
extern void oled_address(const OLEDInfo* oled,
	uint8_t col_start, uint8_t col_end, uint8_t page_start, uint8_t page_end);


/**
 * settings for horizontal scrolling
 */
extern void oled_scroll_setup_h(const OLEDInfo* oled, bool left,
	uint8_t page_start, uint8_t page_end, uint8_t speed);


/**
 * settings for horizontal/vertical scrolling
 */
extern void oled_scroll_setup_hv(const OLEDInfo* oled, bool left,
	uint8_t page_start, uint8_t page_end, uint8_t speed, uint8_t v_offs);


/**
 * scroll area
 */
extern void oled_scroll_setup_area(const OLEDInfo* oled,
	uint8_t row_start, uint8_t num_rows);


/**
 * enable/disable scrolling
 */
extern void oled_scroll(const OLEDInfo* oled, bool enable);


/**
 * clear the screen
 */
extern void oled_clear(const OLEDInfo* oled, uint8_t clear_val);


/**
 * draw a pixel
 */
extern void oled_pixel(const OLEDInfo* oled, uint16_t x, uint16_t y, bool set);


/**
 * draw the framebuffer
 */
extern void oled_update(const OLEDInfo* oled);


#endif
