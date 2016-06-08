/*
    $Id: avc.h 231 2011-06-27 13:46:19Z marc.noirot $

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
#ifndef __AVC_H__
#define __AVC_H__

#include <stdio.h>

#include "types.h"
#include "flv.h"

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

int read_avc_resolution(flv_stream * f, uint32 body_length, uint32 * width, uint32 * height);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __AVC_H__ */
