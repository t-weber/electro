/**
 * oled test
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 *   - https://www.instructables.com/Getting-Started-With-OLED-Displays/
 */

#include "oled.c"


/*---------------------------------------------------------------------------*/
/* i2c interface */
/*---------------------------------------------------------------------------*/
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
/*---------------------------------------------------------------------------*/


/* oled display */
static OLEDInfo oled;


void setup()
{
	/* set up oled */
	oled.delay = &delay;
	oled.width = 128;
	oled.height = 64;
	oled.i2c_addr = 0x3c;
	oled.i2c_begin = &wire_begin_transmission;
	oled.i2c_end = &wire_end_transmission;
	oled.i2c_write = &wire_write;

	Wire.begin();
	oled_init(&oled);
}


void loop()
{
}
