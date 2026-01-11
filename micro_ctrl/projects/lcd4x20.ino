/**
 * 4x20 lcd test
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 *   - S. Fitzgerald and M. Shiloh, "Arduino Projects Book" (2013).
 */

#define USE_2WIRE

#include "lcd.c"
#include "string.c"


#ifdef USE_2WIRE
	#include <Wire.h>

	static void wire_begin_transmission(uint8_t addr)
	{
		Wire.beginTransmission(addr);
	}

	static void wire_end_transmission(uint8_t addr)
	{
		Wire.endTransmission(addr);
	}

	static void wire_write(uint8_t data)
	{
		Wire.write(data);
	}
#endif


/* lc display */
static LCDInfo lcd;


void setup()
{
	/* set up lcd */
	lcd.delay = &delay;
#ifdef USE_2WIRE
	lcd.pin_mode = 0; /* scl -> a5, sda -> a4 */
	lcd.wire_addr = 0x27;
	lcd.wire_begin = &wire_begin_transmission;
	lcd.wire_end = &wire_end_transmission;
	lcd.wire_write = &wire_write;

	Wire.begin();
#else
	lcd.pin_mode = 1;
	lcd.set_pin = &digitalWrite;
	lcd.pin_set = HIGH;
	lcd.pin_unset = LOW;
	lcd.pin_en = 6;
	lcd.pin_rs = 7;
	lcd.pin_d4 = 2;
	lcd.pin_d5 = 3;
	lcd.pin_d6 = 4;
	lcd.pin_d7 = 5;

	/* lcd output pins */
	pinMode(lcd.pin_en, OUTPUT);
	pinMode(lcd.pin_rs, OUTPUT);
	pinMode(lcd.pin_d4, OUTPUT);
	pinMode(lcd.pin_d5, OUTPUT);
	pinMode(lcd.pin_d6, OUTPUT);
	pinMode(lcd.pin_d7, OUTPUT);
#endif

	/*
	 * initialise lcd
	 * @see https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
	 */
	lcd_init(&lcd);
	lcd_set_function(&lcd, 0, 1, 0);
	lcd_set_display(&lcd, 1, 0, 0);
	lcd_clear(&lcd);
	lcd_return(&lcd);
	lcd_set_caret_direction(&lcd, 1, 0);
}


void loop()
{
	lcd_set_address(&lcd, 1, 0*20);
	lcd_puts(&lcd, "Line 1: abcdefghijkl");

	lcd_set_address(&lcd, 1, 1*20);
	lcd_puts(&lcd, "Line 3: ABCDEFGHIJKL");

	lcd_set_address(&lcd, 1, 2*20);
	lcd_puts(&lcd, "Line 2: 123456789012");

	lcd_set_address(&lcd, 1, 4*21);
	lcd_puts(&lcd, "Line 4: 987654321098");

	delay(1000);
}
