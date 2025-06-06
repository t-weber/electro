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
	t_real len, const t_real* trafo,
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

	/* draw cube edges */
	draw_line(vertices[0][0], vertices[0][1], vertices[2][0], vertices[2][1], draw_func, user_data);
	draw_line(vertices[0][0], vertices[0][1], vertices[4][0], vertices[4][1], draw_func, user_data);
	draw_line(vertices[1][0], vertices[1][1], vertices[3][0], vertices[3][1], draw_func, user_data);
	draw_line(vertices[1][0], vertices[1][1], vertices[5][0], vertices[5][1], draw_func, user_data);
	draw_line(vertices[2][0], vertices[2][1], vertices[6][0], vertices[6][1], draw_func, user_data);
	draw_line(vertices[3][0], vertices[3][1], vertices[7][0], vertices[7][1], draw_func, user_data);
	draw_line(vertices[4][0], vertices[4][1], vertices[6][0], vertices[6][1], draw_func, user_data);
	draw_line(vertices[5][0], vertices[5][1], vertices[7][0], vertices[7][1], draw_func, user_data);

	draw_line(vertices[0][0], vertices[0][1], vertices[1][0], vertices[1][1], draw_func, user_data);
	draw_line(vertices[2][0], vertices[2][1], vertices[3][0], vertices[3][1], draw_func, user_data);
	draw_line(vertices[4][0], vertices[4][1], vertices[5][0], vertices[5][1], draw_func, user_data);
	draw_line(vertices[6][0], vertices[6][1], vertices[7][0], vertices[7][1], draw_func, user_data);
}
