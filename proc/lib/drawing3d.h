/**
 * draws shapes
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 */


#ifndef __DRAW_SHAPES_3D_H__
#define __DRAW_SHAPES_3D_H__

#include "defines.h"
#include "maths.h"


/**
 * draw a cube
 */
extern void draw_cube(
	t_real len, const t_real* trafo,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data);


#endif
