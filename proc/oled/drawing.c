/**
 * draws shapes
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 */

#include "drawing.h"

#include <math.h>
#include <stdlib.h>


static inline bool pixel_in_bounds(t_int x, t_int inc, t_int end)
{
	if(inc > 0)
		return x <= end;
	return x >= end;
};


/**
 * bresenham algorithm
 * @see https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
 * @see https://de.wikipedia.org/wiki/Bresenham-Algorithmus
 */
void draw_line(
	t_int x_start, t_int y_start,
	t_int x_end, t_int y_end,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data)
{
	const t_int x_range = x_end - x_start;
	const t_int y_range = y_end - y_start;
	const t_int x_range_abs = abs(x_range);
	const t_int y_range_abs = abs(y_range);

	const t_int x_inc = x_range > 0 ? 1 : -1;
	const t_int y_inc = y_range > 0 ? 1 : -1;


	/* special cases: straight line */
	if(x_range == 0)
	{
		for(t_int y=y_start; pixel_in_bounds(y, y_inc, y_end); y+=y_inc)
			draw_func(user_data, x_start, y);
		return;
	}

	if(y_range == 0)
	{
		for(t_int x=x_start; pixel_in_bounds(x, x_inc, x_end); x+=x_inc)
			draw_func(user_data, x, y_start);
		return;
	}


	/* general case: sloped line with x range larger than y range */
	if(x_range_abs >= y_range_abs)
	{
		const t_int mult = 2;
		t_int y = y_start;
		t_int err = x_range * mult/2;

		for(t_int x=x_start; pixel_in_bounds(x, x_inc, x_end); x+=x_inc)
		{
			draw_func(user_data, x, y);
			err -= mult * y_range;

			if(err < 0 && y_inc > 0)
			{
				y += y_inc;
				err += mult * x_range_abs;
			}

			if(err > 0 && y_inc < 0)
			{
				y += y_inc;
				err -= mult * x_range_abs;
			}
		}
	}


	/* general case: sloped line with y range larger than x range */
	else
	{
		const t_int mult = 2;
		t_int x = x_start;
		t_int err = y_range * mult/2;

		for(t_int y=y_start; pixel_in_bounds(y, y_inc, y_end); y+=y_inc)
		{
			draw_func(user_data, x, y);
			err -= mult * x_range;

			if(err < 0 && x_inc > 0)
			{
				x += x_inc;
				err += mult * y_range_abs;
			}

			else if(err > 0 && x_inc < 0)
			{
				x += x_inc;
				err -= mult * y_range_abs;
			}
		}
	}
}


/**
 * bresenham algorithm
 * @see https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
 * @see https://de.wikipedia.org/wiki/Bresenham-Algorithmus
 */
void draw_rect(
	t_int x1, t_int y1,
	t_int x2, t_int y2,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data)
{
	draw_line(x1, y1, x2, y1, draw_func, user_data);
	draw_line(x1, y1, x1, y2, draw_func, user_data);
	draw_line(x2, y2, x1, y2, draw_func, user_data);
	draw_line(x2, y2, x2, y1, draw_func, user_data);
}


/**
 * bresenham circle algorithm
 * @see https://de.wikipedia.org/wiki/Bresenham-Algorithmus#Kreisvariante_des_Algorithmus
 */
void draw_circle(
	t_int x_centre, t_int y_centre,
	t_int rad,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data)
{
	t_int x = rad;
	for(t_int y=0, err=-x; y<x; ++y, err+=2*y + 1)
	{
		if(err > 0)
		{
			err -= 2*x - 1;
			--x;
		}

		draw_func(user_data, x_centre + x, y_centre + y);
		draw_func(user_data, x_centre + x, y_centre - y);
		draw_func(user_data, x_centre - x, y_centre + y);
		draw_func(user_data, x_centre - x, y_centre - y);
	}


	t_int y = rad;
	for(t_int x=0, err=-y; x<y; ++x, err+=2*x + 1)
	{
		if(err > 0)
		{
			err -= 2*y - 1;
			--y;
		}

		draw_func(user_data, x_centre + x, y_centre + y);
		draw_func(user_data, x_centre + x, y_centre - y);
		draw_func(user_data, x_centre - x, y_centre + y);
		draw_func(user_data, x_centre - x, y_centre - y);
	}
}
