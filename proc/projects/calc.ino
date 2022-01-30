/**
 * calculator
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 *   - https://www.instructables.com/Getting-Started-With-OLED-Displays/
 *   - https://www.arduino.cc/reference/en/language/functions/external-interrupts/attachinterrupt/
 */

#include "lib/oled.c"
#include "lib/maths.c"
#include "lib/string.c"
#include "lib/expr.c"


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


/*---------------------------------------------------------------------------*/
/* oled display */
/*---------------------------------------------------------------------------*/
static OLEDInfo oled;
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* parser */
/*---------------------------------------------------------------------------*/
struct ParserContext parser;
/*---------------------------------------------------------------------------*/


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

	/* set up oled i2c bus */
	Wire.begin();
	Wire.setClock(400000ul);
	oled_init(&oled);

	/* set up parser */
	init_parser(&parser);


	t_value result = parse(&parser, "(1 + 2) * 3 + 5");
	char result_str[16];
#ifdef EXPR_PARSER_USE_INTEGER
	int_to_str(result, 10, result_str);
#else
	real_to_str(result, 10, result_str, 2);
#endif

	oled_clear(&oled, 0);
	oled_set_cursor(&oled, 0, 0);
	oled_puts(&oled, result_str);
	oled_update(&oled);

}


void loop()
{
	delay(50);
}
