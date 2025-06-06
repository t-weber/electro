/**
 * tests the drawing functions
 * @author Tobias Weber
 * @date june-2025
 * @license see 'LICENSE' file
 *
 * gcc -o test_drawing3d test_drawing3d.c ../lib/drawing3d.c ../lib/drawing.c ../lib/maths.c -lm -lpng
 */

#include "../lib/drawing3d.h"
#include "../lib/drawing.h"
#include "../lib/maths.h"

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <png.h>


typedef struct
{
	/* image buffer */
	t_int height;
	t_int width;
	uint8_t *data;

	/* image file */
	FILE *img_file;
	png_structp img_main;
	png_infop img_info;
} Image;


/* image error function */
static void img_error_msg(const png_structp png, const char* err)
{
	fprintf(stderr, "Image warning or error: %s.", err);
}


/**
 * draws a pixel into the image buffer
 */
static void draw_func(void *user_data, t_int x, t_int y)
{
	Image *image = (Image*)user_data;
	if(x < 0 || y < 0 || x >= image->width || y >= image->height)
		return;

	/* printf("draw: (%d, %d)\n", x, y); */
	image->data[y*image->width + x] = 0xff;
}


int main(int argc, char **argv)
{
	/* get command-line arguments */
	if(argc < 4)
	{
		fprintf(stderr, "Usage: %s <angle_x> <angle_y> <image>\n", argv[0]);
		fprintf(stderr, "Example: %s 45 33 cube.png\n", argv[0]);
		return -1;
	}

	const char *angle_x_str = argv[1];
	const char *angle_y_str = argv[2];
	const char *img_filename = argv[3];


	/* set-up image */
	Image image;
	memset(&image, 0, sizeof(image));

	image.height = 512;
	image.width = 512;
	t_int linewidth = 2;
	bool use_perspective = 1;

	image.data = malloc(image.width*image.height);
	memset(image.data, 0, image.width*image.height);


	/* viewport and perspective */
	t_real mat_viewport[4*4];
	viewport(mat_viewport, image.width, image.height, 0., 1.);

	t_real mat_perspective[4*4];
	if(use_perspective)
	{
		// perspective projection
		perspective(mat_perspective, 0.01, 100., 70./180.*M_PI,
			((t_real)image.height) / ((t_real)image.width), 0, 0, 0);
	}
	else
	{
		// parallel projection
		parallel(mat_perspective, 0.01, 100., -1., 1., -1., 1., 0, 0, 0);
	}

	t_real mat_viewport_perspective[4*4];
	mult_mat(mat_viewport, mat_perspective, mat_viewport_perspective, 4, 4, 4);


	/* cube rotation and translation */
	t_real mat_rotation_x[4*4];
	t_real angle_x = atof(angle_x_str) / 180. * M_PI;
	rotation_x(mat_rotation_x, angle_x);

	t_real mat_rotation_y[4*4];
	t_real angle_y = atof(angle_y_str) / 180. * M_PI;
	rotation_y(mat_rotation_y, angle_y);

	t_real mat_rotation[4*4];
	mult_mat(mat_rotation_y, mat_rotation_x, mat_rotation, 4, 4, 4);

	t_real mat_translation[4*4];
	translation(mat_translation, 0., 0., 1.75);

	t_real cube_trafo[4*4], mat_transrot[4*4];
	mult_mat(mat_translation, mat_rotation, mat_transrot, 4, 4, 4);
	mult_mat(mat_viewport_perspective, mat_transrot, cube_trafo, 4, 4, 4);

	draw_cube(0.5, cube_trafo, linewidth, &draw_func, &image);


	/**
	 * creates an image file,
	 * see: http://www.libpng.org/pub/png/libpng-1.2.5-manual.html#section-4
	 * see: https://refspecs.linuxbase.org/LSB_5.0.0/LSB-Desktop-generic/LSB-Desktop-generic/toclibpng12.html
	 * see: https://github.com/pnggroup/libpng/blob/master/pngwrite.c
	 */
	image.img_main = png_create_write_struct(PNG_LIBPNG_VER_STRING,
		&image /* user data */,
		&img_error_msg, &img_error_msg);
	image.img_info = png_create_info_struct(image.img_main);

	image.img_file = fopen(img_filename, "wb");
	png_init_io(image.img_main, image.img_file);

	png_set_IHDR(image.img_main, image.img_info,
		image.width, image.height, 8, PNG_COLOR_TYPE_GRAY,
		PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
	png_write_info(image.img_main, image.img_info);

	for(t_int y = 0; y < image.height; ++y)
		png_write_row(image.img_main, image.data + y*image.width);
	//png_write_image(image.img_main, image.data);
	png_write_end(image.img_main, image.img_info);
	png_write_flush(image.img_main);


	/* cleanup */
	free(image.data);
	png_destroy_info_struct(image.img_main, &image.img_info);
	png_destroy_write_struct(&image.img_main, &image.img_info);
	fflush(image.img_file);
	fclose(image.img_file);
	return 0;
}
