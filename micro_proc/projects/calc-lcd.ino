/**
 * calculator using a keypad and an lc display
 * @author Tobias Weber
 * @date mar-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - LCD: https://www.arduino.cc/documents/datasheets/LCDscreen.PDF
 *   - Keypad: https://www.tontek.com.tw/product/product2?lang=en&idx=95
 *   - Keypad: https://www.engineersgarage.com/arduino-ttp229-touch-keypad-interfacing/
 *   - Interrupts: https://www.arduino.cc/reference/en/language/functions/external-interrupts/attachinterrupt/
 */

#define USE_2WIRE

#include "lib/keypad.c"
#include "lib/lcd.c"
#include "lib/maths.c"
#include "lib/string.c"
#include "lib/expr.c"


/*---------------------------------------------------------------------------*/
/* 2-wire interface */
/*---------------------------------------------------------------------------*/
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
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* lc display */
/*---------------------------------------------------------------------------*/
#define LINE_LENGTH          16
#define SCREEN_UPDATE_DELAY  200

static LCDInfo lcd;
static volatile bool screen_needs_update;


/**
 * refresh the text on the screen
 */
static void update_screen(
	const char *input_str, const char *output_str)
{
	lcd_clear(&lcd);

	lcd_set_address(&lcd, 1, 0);
	lcd_puts(&lcd, input_str);
	lcd_set_address(&lcd, 1, 40);
	lcd_puts(&lcd, output_str);
}
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* keypad */
/*---------------------------------------------------------------------------*/
#define KEYPAD_NUM_KEYS      16
#define KEYPAD_ACTIVE_HIGH   0
#define KEY_ENTER            0b1000000000000000

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

static char input_str[LINE_LENGTH + 1];
static char output_str[LINE_LENGTH + 1];
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
		if(keystate & (1 << key))
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


	/* set up the lcd */
	screen_needs_update = true;
	lcd.delay = &delay;
#ifdef USE_2WIRE
	lcd.pin_mode = 0;
	lcd.wire_addr = 0x27;
	lcd.wire_begin = &wire_begin_transmission;
	lcd.wire_end = &wire_end_transmission;
	lcd.wire_write = &wire_write;

	Wire.begin();
	/*Wire.setClock(400000ul);*/
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

	delay(SCREEN_UPDATE_DELAY);
}
