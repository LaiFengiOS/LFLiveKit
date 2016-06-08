/*
    $Id: types.c 231 2011-06-27 13:46:19Z marc.noirot $

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
#include "types.h"

#ifndef WORDS_BIGENDIAN

/* swap 64 bits doubles */
typedef union __convert_u {
    uint64 i;
    number64 f;
} convert_u;

number64 swap_number64(number64 n) {
    convert_u c;
    c.f = n;
    c.i = (((c.i & 0x00000000000000FFULL) << 56) |
           ((c.i & 0x000000000000FF00ULL) << 40) |
           ((c.i & 0x0000000000FF0000ULL) << 24) |
           ((c.i & 0x00000000FF000000ULL) << 8)  |
           ((c.i & 0x000000FF00000000ULL) >> 8)  |
           ((c.i & 0x0000FF0000000000ULL) >> 24) |
           ((c.i & 0x00FF000000000000ULL) >> 40) |
           ((c.i & 0xFF00000000000000ULL) >> 56));
    return c.f;
}
#endif /* !defined WORDS_BIGENDIAN */

/* convert native integers into 24 bits big endian integers */
uint24_be uint32_to_uint24_be(uint32 l) {
    uint24_be r;
    r.b[0] = (uint8)((l & 0x00FF0000U) >> 16);
    r.b[1] = (uint8)((l & 0x0000FF00U) >> 8);
    r.b[2] = (uint8) (l & 0x000000FFU);
    return r;
}

#ifdef WIN32

/*
    These functions assume fpos_t is a 64-bit signed integer
*/

file_offset_t lfs_ftell(FILE * stream) {
    fpos_t p;
    if (fgetpos(stream, &p) == 0) {
        return (file_offset_t)p;
    }
    else {
        return -1LL;
    }
}

int lfs_fseek(FILE * stream, file_offset_t offset, int whence) {
    fpos_t p;
    if (fgetpos(stream, &p) == 0) {
        switch (whence) {
            case SEEK_CUR: p += offset; break;
            case SEEK_SET: p = offset; break;
            /*case SEEK_END:; not implemented here */
            default:
                return -1;
        }
        fsetpos(stream, &p);
        return 0;
    }
    else {
        return -1;
    }
}

#endif /* WIN32 */
