/**
 * oled test
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 *
 * References:
 *   - https://cdn-shop.adafruit.com/datasheets/SSD1306.pdf
 *   - https://www.instructables.com/Getting-Started-With-OLED-Displays/
 *   - https://www.arduino.cc/reference/en/language/functions/external-interrupts/attachinterrupt/
 */

#include "../lib/oled.c"
#include "../lib/drawing.c"
#include "../lib/drawing3d.c"
#include "../lib/maths.c"


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

static void oled_draw_func(void* oled, t_int x, t_int y)
{
	oled_pixel((OLEDInfo*)oled, x, y, 1);
}
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* transformation matrices */
/*---------------------------------------------------------------------------*/
static t_real mat_viewport_perspective[4*4];
static volatile t_real angle_inc = 0.05;
/*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*/
/* button */
/*---------------------------------------------------------------------------*/
#define BUTTON_PIN 2

static void button_isr()
{
	// filter spurious interrupts, e.g. due to button bounce
	static unsigned long last_run_time = 0;
	unsigned long run_time = millis();

	if(run_time - last_run_time > 100)
	{
		angle_inc *= -1.;
	}

	last_run_time = run_time;
}
/*---------------------------------------------------------------------------*/


void setup()
{
	/* set up button */
	pinMode(BUTTON_PIN, INPUT);
	int button_interrupt = digitalPinToInterrupt(BUTTON_PIN);
	attachInterrupt(button_interrupt, button_isr, FALLING);

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

	/*oled_scroll_setup_h(&oled, 0, 0, 7, 0);
	oled_scroll(&oled, 1);*/

	/* set up matrices */
	t_real mat_viewport[4*4];
	t_real mat_perspective[4*4];

	t_real ratio = ((t_real)oled.height) / ((t_real)oled.width);
	viewport(mat_viewport, oled.width, oled.height, 0., 1.);
	perspective(mat_perspective, 0.01, 100., 0.5*M_PI, ratio, 0, 0, 0);
	mult_mat(mat_viewport, mat_perspective, mat_viewport_perspective, 4, 4, 4);
}


void loop()
{
	oled_clear(&oled, 0);

	/*static int x = 50;
	oled_pixel(&oled, x, 40, 1);
	draw_line(10, 10, 100, 20, &oled_draw_func, &oled);
	draw_circle(x, 40, 15, &oled_draw_func, &oled);
	oled_update(&oled);

	++x;
	x %= oled.width;*/

	static t_real angle = 0.;
	t_real cube_trafo[4*4];

	t_real mat_rotation[4*4];
	rotation_y(mat_rotation, angle);

	t_real mat_translation[4*4];
	translation(mat_translation, 0., 0., 1.25);

	t_real mat_tmp[4*4];
	mult_mat(mat_translation, mat_rotation, mat_tmp, 4, 4, 4);
	mult_mat(mat_viewport_perspective, mat_tmp, cube_trafo, 4, 4, 4);

	draw_cube(0.5, cube_trafo, &oled_draw_func, &oled);
	oled_update(&oled);

	angle += angle_inc;
	delay(40);
}
