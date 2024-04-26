/**
 * calculator using a keypad and an oled display
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - OLED: https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 *   - OLED: https://www.instructables.com/Getting-Started-With-OLED-Displays/
 *   - Keypad: https://www.tontek.com.tw/product/product2?lang=en&idx=95
 *   - Keypad: https://www.engineersgarage.com/arduino-ttp229-touch-keypad-interfacing/
 *   - Interrupts: https://www.arduino.cc/reference/en/language/functions/external-interrupts/attachinterrupt/
 */

#include "lib/keypad.c"
#include "lib/oled.c"
#include "lib/maths.c"
#include "lib/string.c"
#include "lib/expr.c"


/*---------------------------------------------------------------------------*/
/* 2-wire interface */
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
#define OLED_UPDATE_DELAY  200

static OLEDInfo oled;
static volatile bool screen_needs_update;


/**
 * refresh the text on the screen
 */
static void update_screen(
	const char *input_str, const char *output_str)
{
	oled_clear(&oled, 0);

	oled_set_cursor(&oled, 0, 0 * g_characters_height);
	oled_puts(&oled, input_str);
	oled_set_cursor(&oled, 0, 2 * g_characters_height);
	oled_puts(&oled, output_str);

	oled_update(&oled);
}
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* keypad */
/*---------------------------------------------------------------------------*/
#define KEYPAD_NUM_KEYS     16
#define KEYPAD_ACTIVE_HIGH  0
#define KEY_ENTER           0b1000000000000000

static KeypadInfo keypad;


/**
 * keypad interrupt service routine
 */
static void keypad_isr_wrapper()
{
	/* noInterrupts(); */
	keypad_isr(&keypad);
	/* interrupts(); */
}
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* parser */
/*---------------------------------------------------------------------------*/
static struct ParserContext parser;

static char input_str[17];
static char output_str[17];
static volatile bool clear_inout;


/**
 * event handler when a key has been pressed
 */
static void key_pressed(uint16_t keystate)
{
	static const char keychar[KEYPAD_NUM_KEYS - 1] =
	{
		'1', '2', '3', '4', '5',
		'6', '7', '8', '9', '0',
		'+', '-', '*', '/', '%',
	};

	/* clear the input and output buffers */
	if(clear_inout)
	{
		input_str[0] = 0;
		output_str[0] = 0;
		clear_inout = false;
	}

	for(uint8_t key = 0; key < KEYPAD_NUM_KEYS - 1; ++key)
	{
		if (keystate & (1 << key))
		strncat_char(input_str, keychar[key], sizeof(input_str));
	}


	if(keystate & KEY_ENTER)
	{
		/* calculate expression */
		t_value result = parse(&parser, input_str);

		/* write output string */
		my_strncpy(output_str, "= ", sizeof(output_str));
#ifdef EXPR_PARSER_USE_INTEGER
		int_to_str(result, 10, output_str + 2);
#else
		real_to_str(result, 10, output_str + 2, 2);
#endif

		clear_inout = true;
	}

	screen_needs_update = true;
}
/*---------------------------------------------------------------------------*/


void setup()
{
	/* set up the parser */
	init_parser(&parser);
	input_str[0] = output_str[0] = 0;
	clear_inout = true;

	/* set up the oled */
	screen_needs_update = true;
	oled.delay = &delay;
	oled.width = 128;
	oled.height = 64;
	oled.wire_addr = 0x3c;
	oled.wire_begin = &wire_begin_transmission;
	oled.wire_end = &wire_end_transmission;
	oled.wire_write = &wire_write;

	/* set up the oled 2-wire bus */
	Wire.begin();
	Wire.setClock(400000ul);
	oled_init(&oled);

	/* set up the keypad */
	keypad.num_keys = KEYPAD_NUM_KEYS;
	keypad.pin_clock = 3;
	keypad.pin_data = 2;
	keypad.pin_set = KEYPAD_ACTIVE_HIGH ? HIGH : LOW;
	keypad.pin_unset = KEYPAD_ACTIVE_HIGH ? LOW : HIGH;
	keypad.set_pin = &digitalWrite;
	keypad.get_pin = &digitalRead;
	keypad.delay = &delayMicroseconds;
	keypad.uptime = &millis;
	keypad.key_pressed_event = &key_pressed;
	keypad_init(&keypad);

	pinMode(keypad.pin_clock, OUTPUT);
	pinMode(keypad.pin_data, INPUT);
	digitalWrite(keypad.pin_clock, keypad.pin_unset);
	int keypad_interrupt = digitalPinToInterrupt(keypad.pin_data);
	attachInterrupt(keypad_interrupt, &keypad_isr_wrapper,
		KEYPAD_ACTIVE_HIGH ? FALLING : RISING);
}


void loop()
{
	if(screen_needs_update && !keypad.isr_busy)
	{
		update_screen(input_str, output_str);
		screen_needs_update = false;
	}

	delay(OLED_UPDATE_DELAY);
}
