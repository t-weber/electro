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

#include "lib/oled.c"
#include "lib/maths.c"
#include "lib/string.c"
#include "lib/expr.c"

/* #define SERIAL_DEBUGGING */


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
#define OLED_UPDATE_DELAY  200


static OLEDInfo oled;
static volatile bool screen_needs_update;


/**
 * refresh the text on the screen
 */
static void update_screen(
	const char *input_str, const char *buffer_str, const char *output_str)
{
	oled_clear(&oled, 0);

	oled_set_cursor(&oled, 0, 0*g_characters_height);
	oled_puts(&oled, input_str);
	oled_set_cursor(&oled, 0, 2*g_characters_height);
	oled_puts(&oled, buffer_str);
	oled_set_cursor(&oled, 0, 3*g_characters_height);
	oled_puts(&oled, output_str);

	oled_update(&oled);
}
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* keypad */
/*---------------------------------------------------------------------------*/
#define KEYPAD_DATA_PIN    2
#define KEYPAD_CLOCK_PIN   3
#define KEYPAD_NUM_KEYS    16
#define KEYPAD_ACTIVE_HIGH 0
#define KEYPAD_ISR_DELAY   200
#define KEYPAD_INIT_DELAY  10
#define KEYPAD_PULSE_DELAY 500


static volatile bool keypad_isr_busy;


/**
 * event handler when a key has been pressed
 */
static void key_pressed(uint16_t);


/**
 * keypad interrupt service routine
 */
static void keypad_isr()
{
	/* noInterrupts(); */
	/* filter spurious interrupts, e.g. due to button bounce */
	static unsigned long last_run_time = 0;
	unsigned long run_time = millis();

	if(run_time - last_run_time > KEYPAD_ISR_DELAY)
	{
		keypad_isr_busy = true;
		delayMicroseconds(KEYPAD_INIT_DELAY);

		uint16_t keystate = 0;
		for(int8_t key=0; key<KEYPAD_NUM_KEYS; ++key)
		{
			/* create a rising (or falling) edge*/
			digitalWrite(KEYPAD_CLOCK_PIN, KEYPAD_ACTIVE_HIGH ? LOW : HIGH);
			delayMicroseconds(KEYPAD_PULSE_DELAY);
			digitalWrite(KEYPAD_CLOCK_PIN, KEYPAD_ACTIVE_HIGH ? HIGH : LOW);
			delayMicroseconds(KEYPAD_PULSE_DELAY);

			/* read the data pin after the clock edge signal */
#if KEYPAD_ACTIVE_HIGH
			bool pressed = (digitalRead(KEYPAD_DATA_PIN) == HIGH);
#else
			bool pressed = (digitalRead(KEYPAD_DATA_PIN) == LOW);
#endif
			/* set the corresponding bit if the key is pressed */
			if(pressed)
				keystate |= (1 << key);
		}

#ifdef SERIAL_DEBUGGING
		char buf[16];
		int_to_str(keystate, 10, buf);
		Serial.println(buf);
#endif

		if(keystate)
			key_pressed(keystate);

		keypad_isr_busy = false;
	}

	last_run_time = run_time;
	/* interrupts(); */
}
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* parser */
/*---------------------------------------------------------------------------*/
static struct ParserContext parser;

static char input_str[17];
static char buffer_str[17];
static char output_str[17];


#define KEY_ENTER 0b1000000000000000


/**
 * event handler when a key has been pressed
 */
static void key_pressed(uint16_t keystate)
{
	static const char keychar[KEYPAD_NUM_KEYS-1] =
	{
		'1', '2', '3', '4', '5',
		'6', '7', '8', '9', '0',
		'+', '-', '*', '/', '%',
	};

	for(uint8_t key=0; key<KEYPAD_NUM_KEYS-1; ++key)
	{
		if(keystate & (1<<key))
		strncat_char(input_str, keychar[key], sizeof(input_str));
	}


	if(keystate & KEY_ENTER)
	{
		/* calculate expression */
		t_value result = parse(&parser, input_str);

		/* write output string */
		my_strncpy(output_str, "= ", sizeof(output_str));
#ifdef EXPR_PARSER_USE_INTEGER
		int_to_str(result, 10, output_str+2);
#else
		real_to_str(result, 10, output_str+2, 2);
#endif

		/* copy input string to buffer and clear it */
		my_strncpy(buffer_str, input_str, sizeof(input_str));
		input_str[0] = 0;
	}

	screen_needs_update = true;
}
/*---------------------------------------------------------------------------*/


void setup()
{
	/* set up the parser */
	init_parser(&parser);
	input_str[0] = buffer_str[0] = output_str[0] = 0;

#ifdef SERIAL_DEBUGGING
	Serial.begin(9600);
#endif

	/* set up the oled */
	screen_needs_update = true;
	oled.delay = &delay;
	oled.width = 128;
	oled.height = 64;
	oled.i2c_addr = 0x3c;
	oled.i2c_begin = &wire_begin_transmission;
	oled.i2c_end = &wire_end_transmission;
	oled.i2c_write = &wire_write;

	/* set up the oled i2c bus */
	Wire.begin();
	Wire.setClock(400000ul);
	oled_init(&oled);

	/* set up the keypad */
	keypad_isr_busy = false;
	pinMode(KEYPAD_CLOCK_PIN, OUTPUT);
	pinMode(KEYPAD_DATA_PIN, INPUT);
	digitalWrite(KEYPAD_CLOCK_PIN, KEYPAD_ACTIVE_HIGH ? LOW : HIGH);
	int keypad_interrupt = digitalPinToInterrupt(KEYPAD_DATA_PIN);
	attachInterrupt(keypad_interrupt, &keypad_isr,
		KEYPAD_ACTIVE_HIGH ? FALLING : RISING);
}


void loop()
{
	if(!keypad_isr_busy && screen_needs_update)
	{
		update_screen(input_str, buffer_str, output_str);
		screen_needs_update = false;
	}

	delay(OLED_UPDATE_DELAY);
}
