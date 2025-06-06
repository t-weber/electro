/**
 * keypad module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * @see https://www.tontek.com.tw/product/product2?lang=en&idx=95
 * @see https://www.engineersgarage.com/arduino-ttp229-touch-keypad-interfacing/
 */

#ifndef __MY_KEYPAD_H__
#define __MY_KEYPAD_H__

#include "defines.h"


typedef struct _KeypadInfo
{
	uint8_t num_keys;
	volatile bool isr_busy;

	/* callback function for key presses */
	void (*key_pressed_event)(uint16_t keystate);

	/*------------------------------------------------------------*/
	/* pins */
	/*------------------------------------------------------------*/
	/* enable and register select pins */
	uint8_t pin_clock;
	uint8_t pin_data;

	/* are the pins active high or active low? */
	/* bool active_high; */

	/* constants for set or unset pins */
	uint8_t pin_set;
	uint8_t pin_unset;

	/* (microcontroller's) input/output functions */
	int (*get_pin)(uint8_t pin);
	void (*set_pin)(uint8_t pin, uint8_t state);
	/*------------------------------------------------------------*/

	/* (microcontroller's) delay function */
	void (*delay)(unsigned int microsecs);
	unsigned long (*uptime)();
} KeypadInfo;


/**
 * initialise the display
 */
extern void keypad_init(KeypadInfo* keypad);


/**
 * keypad interrupt service routine
 */
extern void keypad_isr(KeypadInfo* keypad);


#endif
