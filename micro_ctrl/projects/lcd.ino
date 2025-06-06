/**
 * displays temperature on lcd
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 *   - https://www.arduino.cc/documents/datasheets/TEMP-TMP35_36_37.pdf
 *   - S. Fitzgerald and M. Shiloh, "Arduino Projects Book" (2013).
 */

#define USE_2WIRE

#include "lib/lcd.c"
#include "lib/string.c"

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
	/* temperature input pin */
	pinMode(A0, INPUT);

	/* set up lcd */
	lcd.delay = &delay;
#ifdef USE_2WIRE
	lcd.pin_mode = 0;
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

	/* set up 8 custom characters */
	lcd_set_address(&lcd, 0, 0);
	for(uint8_t char_idx=0; char_idx<8; ++char_idx)
	{
		for(uint8_t line=0; line<8; ++line)
		{
			if(line == char_idx)
				lcd_send_byte(&lcd, 1, 0b00011111);
			else
				lcd_send_byte(&lcd, 1, 0b00000000);
		}
	}
}


void loop()
{
	/*
	 * print temperature
	 * voltage to temperature conversion
	 * @see https://www.arduino.cc/documents/datasheets/TEMP-TMP35_36_37.pdf
	 */
	/* 5000 mV circuit */
	static const float U_range = 5000.;
	/* temperature sensor value range */
	static const float a0_range = 1024.;
	/* temperature sensor curve slope [degC/mV] */
	static const float T_slope = 0.1;
	/* voltage at T = 0 degC */
	static const float U_T0 = 750 - 25./T_slope;

	float a0 = (float)analogRead(A0);
	float U = a0 / a0_range * U_range;
	float T = (U - U_T0)*T_slope;

	t_char temp[16];
	real_to_str(T, 10, temp, 1);

	lcd_set_address(&lcd, 1, 3);
	lcd_puts(&lcd, "T = ");
	lcd_puts(&lcd, temp);
	lcd_puts(&lcd, "\xdf" "C  ");

	/* print maximum temperature */
	static float T_max = T;
	if(T > T_max)
		T_max = T;
	real_to_str(T_max, 10, temp, 1);

	lcd_set_address(&lcd, 1, 40);
	lcd_puts(&lcd, "Tmax = ");
	lcd_puts(&lcd, temp);
	lcd_puts(&lcd, "\xdf" "C  ");

	/* print activity animation */
	static uint8_t anim_idx = 0;
	lcd_set_address(&lcd, 1, 0);
	lcd_send_byte(&lcd, 1, anim_idx);
	lcd_set_address(&lcd, 1, 15);
	lcd_send_byte(&lcd, 1, anim_idx);
	++anim_idx %= 8;

	delay(250);
}
