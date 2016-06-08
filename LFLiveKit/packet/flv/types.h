/*
    $Id: types.h 231 2011-06-27 13:46:19Z marc.noirot $

    FLV Metadata updater

    Copyright (C) 2007-2012 Marc Noirot <marc.noirot AT gmail.com>

    This file is part of FLVMeta.

    FLVMeta is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    FLVMeta is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with FLVMeta; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*/
#ifndef __TYPES_H__
#define __TYPES_H__

#include <stdint.h>

#include <stdio.h>

typedef uint8_t byte, uint8, uint8_bitmask;

typedef uint16_t uint16, uint16_be, uint16_le;

typedef int16_t sint16, sint16_be, sint16_le;

typedef uint32_t uint32, uint32_be, uint32_le;

typedef int32_t sint32, sint32_be, sint32_le;

typedef struct __uint24 {
    uint8 b[3];
} uint24, uint24_be, uint24_le;

typedef uint64_t uint64, uint64_le, uint64_be;

typedef int64_t sint64, sint64_le, sint64_be;

//typedef
//#if SIZEOF_FLOAT == 8
//float
//#elif SIZEOF_DOUBLE == 8
//double
//#elif SIZEOF_LONG_DOUBLE == 8
//long double
//#else
//uint64_t
//#endif
//number64, number64_le, number64_be;

typedef double number64, number64_le, number64_be;

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

#ifdef WORDS_BIGENDIAN

# define swap_uint16(x) (x)
# define swap_sint16(x) (x)
# define swap_uint32(x) (x)
# define swap_number64(x) (x)

#else /* !defined WORDS_BIGENDIAN */

/* swap 16 bits integers */
# define swap_uint16(x) ((uint16)((((x) & 0x00FFU) << 8) | \
    (((x) & 0xFF00U) >> 8)))
# define swap_sint16(x) ((sint16)((((x) & 0x00FF) << 8) | \
    (((x) & 0xFF00) >> 8)))

/* swap 32 bits integers */
# define swap_uint32(x) ((uint32)((((x) & 0x000000FFU) << 24) | \
    (((x) & 0x0000FF00U) << 8)  | \
    (((x) & 0x00FF0000U) >> 8)  | \
    (((x) & 0xFF000000U) >> 24)))

/* swap 64 bits doubles */
number64 swap_number64(number64);

#endif /* WORDS_BIGENDIAN */

/* convert big endian 24 bits integers to native integers */
# define uint24_be_to_uint32(x) ((uint32)(((x).b[0] << 16) | \
    ((x).b[1] << 8) | (x).b[2]))

/* convert native integers into 24 bits big endian integers */
uint24_be uint32_to_uint24_be(uint32);

/* large file support */
#ifdef HAVE_FSEEKO
# define lfs_ftell ftello
# define lfs_fseek fseeko

# define FILE_OFFSET_T_64_BITS 1
typedef off_t file_offset_t;

#else /* !HAVE_SEEKO */

# ifdef WIN32

# define FILE_OFFSET_T_64_BITS 1
typedef long long int file_offset_t;

/* Win32 large file support */
file_offset_t lfs_ftell(FILE * stream);
int lfs_fseek(FILE * stream, file_offset_t offset, int whence);

# else /* !defined WIN32 */

# define lfs_ftell ftell
# define lfs_fseek fseek

typedef long file_offset_t;

# endif /* WIN32 */

#endif /* HAVE_FSEEKO */

/* file offset printf specifier */
#ifdef FILE_OFFSET_T_64_BITS
# define FILE_OFFSET_PRINTF_FORMAT "ll"
#else
# define FILE_OFFSET_PRINTF_FORMAT "l"
#endif

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __TYPES_H__ */
