/**
 * keypad module
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * @see https://www.tontek.com.tw/product/product2?lang=en&idx=95
 * @see https://www.engineersgarage.com/arduino-ttp229-touch-keypad-interfacing/
 */

#include "keypad.h"


#define KEYPAD_ISR_DELAY   200
#define KEYPAD_INIT_DELAY  10
#define KEYPAD_PULSE_DELAY 500



/**
 * initialise the keypad
 */
void keypad_init(KeypadInfo* keypad)
{
	keypad->isr_busy = false;
}


/**
 * keypad interrupt service routine
 */
void keypad_isr(KeypadInfo* keypad)
{
	/* noInterrupts(); */
	/* filter spurious interrupts, e.g. due to button bounce */
	static unsigned long last_run_time = 0;
	unsigned long run_time = keypad->uptime();

	if(run_time - last_run_time > KEYPAD_ISR_DELAY)
	{
		keypad->isr_busy = true;
		keypad->delay(KEYPAD_INIT_DELAY);

		uint16_t keystate = 0;
		for(uint8_t key=0; key<keypad->num_keys; ++key)
		{
			/* create a rising (or falling) edge*/
			keypad->set_pin(keypad->pin_clock, keypad->pin_unset);
			keypad->delay(KEYPAD_PULSE_DELAY);
			keypad->set_pin(keypad->pin_clock, keypad->pin_set);
			keypad->delay(KEYPAD_PULSE_DELAY);

			/* read the data pin after the clock edge signal */
			bool pressed = (keypad->get_pin(keypad->pin_data) == keypad->pin_set);

			/* set the corresponding bit if the key is pressed */
			if(pressed)
				keystate |= (1 << key);
		}

		if(keystate)
			keypad->key_pressed_event(keystate);

		keypad->isr_busy = false;
	}

	last_run_time = run_time;
	/* interrupts(); */
}
