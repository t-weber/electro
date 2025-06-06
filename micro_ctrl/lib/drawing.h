/**
 * draws shapes
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 */


#ifndef __DRAW_SHAPES_H__
#define __DRAW_SHAPES_H__

#include "defines.h"


/**
 * bresenham algorithm
 * @see https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
 * @see https://de.wikipedia.org/wiki/Bresenham-Algorithmus
 */
extern void draw_line(
	t_int x_start, t_int y_start,
	t_int x_end, t_int y_end,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data);


/**
 * bresenham algorithm
 * @see https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
 * @see https://de.wikipedia.org/wiki/Bresenham-Algorithmus
 */
extern void draw_rect(
	t_int x1, t_int y1,
	t_int x2, t_int y2,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data);


/**
 * bresenham circle algorithm
 * @see https://de.wikipedia.org/wiki/Bresenham-Algorithmus#Kreisvariante_des_Algorithmus
 */
extern void draw_circle(
	t_int x_centre, t_int y_centre,
	t_int rad,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data);


#endif
