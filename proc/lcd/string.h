/**
 * simple libc string replacement functions
 * @author Tobias Weber
 * @date mar-21
 * @license see 'LICENSE' file
 */

#ifndef __MY_STRING_H__
#define __MY_STRING_H__

#include "defines.h"


extern void reverse_str(t_char* buf, t_size len);

extern t_char digit_to_char(uint8_t num, t_size base);
extern void uint_to_str(uint32_t num, uint32_t base, t_char* buf);
extern void int_to_str(int32_t num, int32_t base, t_char* buf);
extern void real_to_str(float num, uint32_t base, t_char* buf, uint8_t decimals);

extern int32_t my_atoi(const t_char* str, int32_t base);
extern float my_atof(const t_char* str, int32_t base);

extern void my_strncpy(t_char* str_dst, const t_char* str_src, t_size max_len);
extern void my_strncat(t_char* str_dst, const t_char* str_src, t_size max_len);
extern void strncat_char(t_char* str, t_char c, t_size max_len);

extern int8_t my_strncmp(const t_char* str1, const t_char* str2, t_size max_len);
extern int8_t my_strcmp(const t_char* str1, const t_char* str2);

extern t_size my_strlen(const t_char* str);
extern void my_memset(t_char* mem, t_char val, t_size size);
extern void my_memset_interleaved(t_char* mem, t_char val, t_size size, uint8_t interleave);
extern void my_memcpy(t_char* mem_dst, t_char* mem_src, t_size size);
extern void my_memcpy_interleaved(t_char* mem_dst, t_char* mem_src, t_size size, uint8_t interleave);

extern int32_t my_max(int32_t a, int32_t b);

extern int8_t my_isupperalpha(t_char c);
extern int8_t my_isloweralpha(t_char c);
extern int8_t my_isalpha(t_char c);
extern int8_t my_isdigit(t_char c, int8_t hex);


#endif
