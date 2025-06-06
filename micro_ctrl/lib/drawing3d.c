/**
 * draws shapes
 * @author Tobias Weber
 * @date jan-2022
 * @license see 'LICENSE' file
 */

#include "drawing3d.h"
#include "drawing.h"


/**
 * draw a cube
 */
void draw_cube(
	t_real len, const t_real* trafo, t_int linewidth,
	void (*draw_func)(void*, t_int x, t_int y),
	void *user_data)
{
	t_real vertices[8][4] =
	{
		{ -len, -len, -len, 1. }, /* 0 */
		{ -len, -len, +len, 1. }, /* 1 */
		{ -len, +len, -len, 1. }, /* 2 */
		{ -len, +len, +len, 1. }, /* 3 */
		{ +len, -len, -len, 1. }, /* 4 */
		{ +len, -len, +len, 1. }, /* 5 */
		{ +len, +len, -len, 1. }, /* 6 */
		{ +len, +len, +len, 1. }, /* 7 */
	};

	/* transform the vertices */
	for(t_int i = 0; i < 8; ++i)
	{
		t_real vertex_trafo[4];
		mult_mat_vec(trafo, vertices[i], vertex_trafo, 4, 4);
		mult_vec(vertex_trafo, 1./vertex_trafo[3], 4);

		for(t_int j = 0; j < 4; ++j)
			vertices[i][j] = vertex_trafo[j];
	}

	--linewidth;
	for(t_real y = -linewidth; y <= linewidth; y += 1.)
	for(t_real x = -linewidth; x <= linewidth; x += 1.)
	{
		/* draw cube edges */
		draw_line(vertices[0][0] + x, vertices[0][1] + y,
			vertices[2][0] + x, vertices[2][1] + y, draw_func, user_data);
		draw_line(vertices[0][0] + x, vertices[0][1] + y,
			vertices[4][0] + x, vertices[4][1] + y, draw_func, user_data);
		draw_line(vertices[2][0] + x, vertices[2][1] + y,
			vertices[6][0] + x, vertices[6][1] + y, draw_func, user_data);
		draw_line(vertices[4][0] + x, vertices[4][1] + y,
			vertices[6][0] + x, vertices[6][1] + y, draw_func, user_data);

		draw_line(vertices[1][0] + x, vertices[1][1] + y,
			vertices[3][0] + x, vertices[3][1] + y, draw_func, user_data);
		draw_line(vertices[1][0] + x, vertices[1][1] + y,
			vertices[5][0] + x, vertices[5][1] + y, draw_func, user_data);
		draw_line(vertices[3][0] + x, vertices[3][1] + y,
			vertices[7][0] + x, vertices[7][1] + y, draw_func, user_data);
		draw_line(vertices[5][0] + x, vertices[5][1] + y,
			vertices[7][0] + x, vertices[7][1] + y, draw_func, user_data);

		draw_line(vertices[0][0] + x, vertices[0][1] + y,
			vertices[1][0] + x, vertices[1][1] + y, draw_func, user_data);
		draw_line(vertices[2][0] + x, vertices[2][1] + y,
			vertices[3][0] + x, vertices[3][1] + y, draw_func, user_data);
		draw_line(vertices[4][0] + x, vertices[4][1] + y,
			vertices[5][0] + x, vertices[5][1] + y, draw_func, user_data);
		draw_line(vertices[6][0] + x, vertices[6][1] + y,
			vertices[7][0] + x, vertices[7][1] + y, draw_func, user_data);
	}
}
