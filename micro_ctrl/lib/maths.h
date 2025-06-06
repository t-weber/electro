/**
 * maths library
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 17-apr-20
 * @license see 'LICENSE' file
 */

#include "defines.h"


/**
 * set float epsilon
 */
extern void set_eps(t_real eps);


/**
 * get float epsilon
 */
extern t_real get_eps();


/**
 * tests equality of floating point numbers
 */
extern int equals(t_real x, t_real y, t_real eps);


/**
 * removes a given row and column of a square matrix
 */
extern void submat(const t_real* M, t_int N, t_real* M_new, t_int iremove, t_int jremove);


/**
 * calculates the determinant of a matrix
 */
extern t_real determinant(const t_real* M, t_int N);



/**
 * inverted matrix
 */
extern t_int inverse(const t_real* M, t_real* I, t_int N);


/**
 * matrix-matrix product: RES^i_j = M1^i_k M2^k_j
 */
extern void mult_mat(const t_real* M1, const t_real* M2, t_real *RES, t_int I, t_int J, t_int K);


/**
 * matrix-vector product: RES^i = M^i_j v^j
 */
extern void mult_mat_vec(const t_real* M, const t_real* v, t_real *RES, t_int I, t_int J);


/**
 * multiply a vector with a scalar
 */
extern void mult_vec(t_real *v, t_real val, t_int N);


/**
 * dot product
 */
extern t_real inner(const t_real* v1, const t_real* v2, t_int N);


/**
 * vector 2-norm
 */
extern t_real norm(const t_real* v, t_int N);


/**
 * vector p-norm
 */
extern t_real norm_p(const t_real* v, t_int N, t_real p);


/**
 * matrix power
 */
extern t_int pow_mat(const t_real* M, t_real* P, t_int N, t_int POW);



/**
 * transposed matrix
 */
extern void transpose(const t_real* M, t_real* T, t_int rows, t_int cols);


/**
 * viewport matrix
 * @see https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/glViewport.xml
 */
extern void viewport(t_real* M, t_real w, t_real h, t_real n, t_real f);


/**
 * perspective projection matrix
 * @see https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/gluPerspective.xml
 * @see https://github.com/PacktPublishing/Vulkan-Cookbook/blob/master/Library/Source%20Files/10%20Helper%20Recipes/04%20Preparing%20a%20perspective%20projection%20matrix.cpp
 */
extern void perspective(t_real *M,
	t_real n, t_real f, t_real fov, t_real ratio,
	bool inv_z, bool z01, bool inv_y);


/**
 * parallel projection matrix (homogeneous 4x4)
 * @see https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/glOrtho.xml
 * @see https://github.com/PacktPublishing/Vulkan-Cookbook/blob/master/Library/Source%20Files/10%20Helper%20Recipes/05%20Preparing%20an%20orthographic%20projection%20matrix.cpp
 */
extern void parallel(t_real *M,
	t_real n, t_real f, t_real l, t_real r, t_real b, t_real t,
	bool inv_z, bool z01, bool inv_y);

/**
 * rotation around the x axis
 * @see https://en.wikipedia.org/wiki/Rotation_matrix
 */
extern void rotation_x(t_real *M, t_real angle);


/**
 * rotation around the y axis
 * @see https://en.wikipedia.org/wiki/Rotation_matrix
 */
extern void rotation_y(t_real *M, t_real angle);


/**
 * rotation around the z axis
 * @see https://en.wikipedia.org/wiki/Rotation_matrix
 */
extern void rotation_z(t_real *M, t_real angle);


/**
 * translation matrix
 */
extern void translation(t_real *M, t_real x, t_real y, t_real z);
