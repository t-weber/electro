/**
 * maths library
 * @author Tobias Weber (orcid: 0000-0002-7230-1932)
 * @date 17-apr-20
 * @license see 'LICENSE' file
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <float.h>
#include <math.h>

#include "maths.h"


static t_real g_eps = FLT_EPSILON;



/**
 * set float epsilon
 */
void set_eps(t_real eps)
{
	g_eps = eps;
}


/**
 * get float epsilon
 */
t_real get_eps()
{
	return g_eps;
}


/**
 * tests equality of floating point numbers
 */
int equals(t_real x, t_real y, t_real eps)
{
	t_real diff = x-y;
	if(diff < 0.)
		diff = -diff;
	return diff <= eps;
}


/**
 * removes a given row and column of a square matrix
 */
void submat(const t_real* M, t_int N, t_real* M_new, t_int iremove, t_int jremove)
{
	t_int row_new = 0;
	for(t_int row = 0; row < N; ++row)
	{
		if(row == iremove)
			continue;

		t_int col_new = 0;
		for(t_int col = 0; col < N; ++col)
		{
			if(col == jremove)
				continue;

			M_new[row_new*(N-1) + col_new] = M[row*N + col];
			++col_new;
		}
		++row_new;
	}
}


/**
 * calculates the determinant
 */
t_real determinant(const t_real* M, t_int N)
{
	/* special cases */
	if(N == 0)
		return 0;
	else if(N == 1)
		return M[0];
	else if(N == 2)
		return M[0*N+0]*M[1*N+1] - M[0*N+1]*M[1*N+0];


	/* get row with maximum number of zeros */
	t_int row = 0;
	t_int maxNumZeros = 0;
	for(t_int curRow = 0; curRow < N; ++curRow)
	{
		t_int numZeros = 0;
		for(t_int curCol = 0; curCol < N; ++curCol)
		{
			if(equals(M[curRow*N + curCol], 0, g_eps))
				++numZeros;
		}

		if(numZeros > maxNumZeros)
		{
			row = curRow;
			maxNumZeros = numZeros;
		}
	}


	/* recursively expand determiant along a row */
	t_real fullDet = 0.;

	t_real *sub = (t_real*)calloc((N-1)*(N-1), sizeof(t_real));
	for(t_int col = 0; col < N; ++col)
	{
		const t_real elem = M[row*N + col];
		if(equals(elem, 0, g_eps))
			continue;

		submat(M, N, sub, row, col);
		const t_real sgn = ((row+col) % 2) == 0 ? 1. : -1.;
		fullDet += elem * determinant(sub, N-1) * sgn;
	}
	free(sub);

	return fullDet;
}



/**
 * inverted matrix
 */
t_int inverse(const t_real* M, t_real* I, t_int N)
{
	t_real fullDet = determinant(M, N);

	/* fail if determinant is zero */
	if(equals(fullDet, 0., g_eps))
		return 0;

	t_real *sub = (t_real*)calloc((N-1)*(N-1), sizeof(t_real));
	for(t_int i = 0; i < N; ++i)
	{
		for(t_int j = 0; j < N; ++j)
		{
			submat(M, N, sub, i, j);
			const t_real sgn = ((i+j) % 2) == 0 ? 1. : -1.;
			I[j*N + i] = determinant(sub, N-1) * sgn / fullDet;
		}
	}
	free(sub);

	return 1;
}


/**
 * matrix-matrix product: RES^i_j = M1^i_k M2^k_j
 */
void mult_mat(const t_real* M1, const t_real* M2, t_real *RES, t_int I, t_int J, t_int K)
{
	for(t_int i = 0; i < I; ++i)
	{
		for(t_int j = 0; j < J; ++j)
		{
			RES[i*J + j] = 0.;

			for(t_int k = 0; k < K; ++k)
				RES[i*J + j] += M1[i*K + k]*M2[k*J + j];
		}
	}
}


/**
 * matrix-vector product: RES^i = M^i_j v^j
 */
void mult_mat_vec(const t_real* M, const t_real* v, t_real *RES, t_int I, t_int J)
{
	for(t_int i = 0; i < I; ++i)
	{
		RES[i] = 0.;

		for(t_int j = 0; j < J; ++j)
			RES[i] += M[i*J + j] * v[j];
	}
}


/**
 * multiply a vector with a scalar
 */
void mult_vec(t_real *v, t_real val, t_int N)
{
	for(t_int i = 0; i < N; ++i)
		v[i] *= val;
}


/**
 * dot product
 */
t_real inner(const t_real* v1, const t_real* v2, t_int N)
{
	t_real res = 0;

	for(t_int i = 0; i < N; ++i)
		res += v1[i]*v2[i];

	return res;
}


/**
 * vector 2-norm
 */
t_real norm(const t_real* v, t_int N)
{
	return sqrt(inner(v, v, N));
}


/**
 * vector p-norm
 */
t_real norm_p(const t_real* v, t_int N, t_real p)
{
	t_real val = 0.;

	for(t_int i = 0; i < N; ++i)
		val += fabs(pow(v[i], p));
	val = pow(val, 1./p);

	return val;
}


/**
 * matrix power
 */
t_int pow_mat(const t_real* M, t_real* P, t_int N, t_int POW)
{
	t_int POW_pos = POW<0 ? -POW : POW;
	t_int status = 1;

	/* temporary matrices */
	t_real *Mtmp = (t_real*)calloc(N*N, sizeof(t_real));
	t_real *Mtmp2 = (t_real*)calloc(N*N, sizeof(t_real));

	/* Mtmp = M */
	for(t_int i = 0; i < N; ++i)
		for(t_int j = 0; j < N; ++j)
			Mtmp[i*N + j] = M[i*N + j];

	/* matrix power */
	for(t_int i = 0; i < POW_pos - 1; ++i)
	{
		mult_mat(Mtmp, M, Mtmp2, N, N, N);

		/* Mtmp = Mtmp2 */
		for(t_int i = 0; i < N; ++i)
			for(t_int j = 0; j < N; ++j)
				Mtmp[i*N + j] = Mtmp2[i*N + j];
	}

	/* invert */
	if(POW < 0)
		status = inverse(Mtmp, Mtmp2, N);

	/* P = Mtmp2 */
	for(t_int i = 0; i < N; ++i)
		for(t_int j = 0; j < N; ++j)
			P[i*N + j] = Mtmp2[i*N + j];

	free(Mtmp);
	free(Mtmp2);
	return status;
}


/**
 * transposed matrix
 */
void transpose(const t_real* M, t_real* T, t_int rows, t_int cols)
{
	for(t_int ctr = 0; ctr < rows*cols; ++ctr)
	{
		t_int i = ctr/cols;
		t_int j = ctr%cols;
		T[j*rows + i] = M[i*cols + j];
	}
}


/**
 * viewport matrix
 * @see https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/glViewport.xml
 */
void viewport(t_real* M, t_real w, t_real h, t_real n, t_real f)
{
	t_real d = f - n;
	t_real dp = f + n;

	M[0*4 + 0] = 0.5*w;  M[0*4 + 1] = 0.;     M[0*4 + 2] = 0.;     M[0*4 + 3] = 0.5*w;
	M[1*4 + 0] = 0.;     M[1*4 + 1] = 0.5*h;  M[1*4 + 2] = 0.;     M[1*4 + 3] = 0.5*h;
	M[2*4 + 0] = 0.;     M[2*4 + 1] = 0.;     M[2*4 + 2] = 0.5*d;  M[2*4 + 3] = 0.5*dp;
	M[3*4 + 0] = 0.;     M[3*4 + 1] = 0.;     M[3*4 + 2] = 0.;     M[3*4 + 3] = 1.;
}


/**
 * perspective projection matrix
 * @see https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/gluPerspective.xml
 * @see https://github.com/PacktPublishing/Vulkan-Cookbook/blob/master/Library/Source%20Files/10%20Helper%20Recipes/04%20Preparing%20a%20perspective%20projection%20matrix.cpp
 */
void perspective(t_real* M,
	t_real n, t_real f, t_real fov, t_real ratio,
	bool inv_z, bool z01, bool inv_y)
{
	t_real c = 1./tan(0.5 * fov);
	t_real n0 = z01 ? 0. : n;
	t_real sc = z01 ? 1. : 2.;
	t_real ys = inv_y ? -1. : 1.;
	t_real zs = inv_z ? -1. : 1.;
	t_real d = n - f;
	t_real d0 = n0 + f;

	M[0*4 + 0] = c*ratio; M[0*4 + 1] = 0.;   M[0*4 + 2] = 0.;      M[0*4 + 3] = 0.;
	M[1*4 + 0] = 0.;      M[1*4 + 1] = ys*c; M[1*4 + 2] = 0.;      M[1*4 + 3] = 0.;
	M[2*4 + 0] = 0.;      M[2*4 + 1] = 0.;   M[2*4 + 2] = zs*d0/d; M[2*4 + 3] = sc*n*f/d;
	M[3*4 + 0] = 0.;      M[3*4 + 1] = 0.;   M[3*4 + 2] = -zs;     M[3*4 + 3] = 0.;
}


/**
 * parallel projection matrix (homogeneous 4x4)
 * @see https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/glOrtho.xml
 * @see https://github.com/PacktPublishing/Vulkan-Cookbook/blob/master/Library/Source%20Files/10%20Helper%20Recipes/05%20Preparing%20an%20orthographic%20projection%20matrix.cpp
 */
void parallel(t_real *M,
	t_real n, t_real f, t_real l, t_real r, t_real b, t_real t,
	bool inv_z, bool z01, bool inv_y)
{
	t_real w = r - l;
	t_real h = t - b;
	t_real d = n - f;

	t_real sc = z01 ? 1. : 2.;
	t_real f0 = z01 ? 0. : f;
	t_real ys = inv_y ? -1. : 1.;
	t_real zs = inv_z ? -1. : 1.;

	M[0*4 + 0] = 2./w; M[0*4 + 1] = 0.;      M[0*4 + 2] = 0.;      M[0*4 + 3] = -(r+l)/w;
	M[1*4 + 0] = 0.;   M[1*4 + 1] = 2.*ys/h; M[1*4 + 2] = 0.;      M[1*4 + 3] = -ys*(t+b)/h;
	M[2*4 + 0] = 0.;   M[2*4 + 1] = 0.;      M[2*4 + 2] = sc*zs/d; M[2*4 + 3] = zs*(n+f0)/d;
	M[3*4 + 0] = 0.;   M[3*4 + 1] = 0.;      M[3*4 + 2] = 0.;      M[3*4 + 3] = 1.;
}


/**
 * rotation around the x axis
 * @see https://en.wikipedia.org/wiki/Rotation_matrix
 */
void rotation_x(t_real *M, t_real angle)
{
	t_real s = sin(angle);
	t_real c = cos(angle);

	M[0*4 + 0] = 1.;  M[0*4 + 1] = 0.;  M[0*4 + 2] = 0.;  M[0*4 + 3] = 0.;
	M[1*4 + 0] = 0.;  M[1*4 + 1] = c;   M[1*4 + 2] = -s;  M[1*4 + 3] = 0.;
	M[2*4 + 0] = 0.;  M[2*4 + 1] = s;   M[2*4 + 2] = c;   M[2*4 + 3] = 0.;
	M[3*4 + 0] = 0.;  M[3*4 + 1] = 0.;  M[3*4 + 2] = 0.;  M[3*4 + 3] = 1.;
}


/**
 * rotation around the y axis
 * @see https://en.wikipedia.org/wiki/Rotation_matrix
 */
void rotation_y(t_real *M, t_real angle)
{
	t_real s = sin(angle);
	t_real c = cos(angle);

	M[0*4 + 0] = c;   M[0*4 + 1] = 0.;  M[0*4 + 2] = s;   M[0*4 + 3] = 0.;
	M[1*4 + 0] = 0.;  M[1*4 + 1] = 1.;  M[1*4 + 2] = 0.;  M[1*4 + 3] = 0.;
	M[2*4 + 0] = -s;  M[2*4 + 1] = 0.;  M[2*4 + 2] = c;   M[2*4 + 3] = 0.;
	M[3*4 + 0] = 0.;  M[3*4 + 1] = 0.;  M[3*4 + 2] = 0.;  M[3*4 + 3] = 1.;
}


/**
 * rotation around the z axis
 * @see https://en.wikipedia.org/wiki/Rotation_matrix
 */
void rotation_z(t_real *M, t_real angle)
{
	t_real s = sin(angle);
	t_real c = cos(angle);

	M[0*4 + 0] = c;   M[0*4 + 1] = -s;  M[0*4 + 2] = 0.;  M[0*4 + 3] = 0.;
	M[1*4 + 0] = s;   M[1*4 + 1] = c;   M[1*4 + 2] = 0.;  M[1*4 + 3] = 0.;
	M[2*4 + 0] = 0.;  M[2*4 + 1] = 0.;  M[2*4 + 2] = 1.;  M[2*4 + 3] = 0.;
	M[3*4 + 0] = 0.;  M[3*4 + 1] = 0.;  M[3*4 + 2] = 0.;  M[3*4 + 3] = 1.;
}


/**
 * translation matrix
 */
void translation(t_real *M, t_real x, t_real y, t_real z)
{
	M[0*4 + 0] = 1.;  M[0*4 + 1] = 0.;  M[0*4 + 2] = 0.;  M[0*4 + 3] = x;
	M[1*4 + 0] = 0.;  M[1*4 + 1] = 1.;  M[1*4 + 2] = 0.;  M[1*4 + 3] = y;
	M[2*4 + 0] = 0.;  M[2*4 + 1] = 0.;  M[2*4 + 2] = 1.;  M[2*4 + 3] = z;
	M[3*4 + 0] = 0.;  M[3*4 + 1] = 0.;  M[3*4 + 2] = 0.;  M[3*4 + 3] = 1.;
}
