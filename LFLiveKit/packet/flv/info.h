/*
    $Id: info.h 231 2011-06-27 13:46:19Z marc.noirot $

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
#ifndef __INFO_H__
#define __INFO_H__
#include "flv.h"

typedef struct __flv_info {
    flv_header header;
    uint8 have_video;
    uint8 have_audio;
    uint32 video_width;
    uint32 video_height;
    uint8 video_codec;
    uint32 video_frames_number;
    uint8 audio_codec;
    uint8 audio_size;
    uint8 audio_rate;
    uint8 audio_stereo;
    file_offset_t video_data_size;
    file_offset_t audio_data_size;
    file_offset_t meta_data_size;
    file_offset_t real_video_data_size;
    file_offset_t real_audio_data_size;
    uint32 video_first_timestamp;
    uint32 audio_first_timestamp;
    uint32 first_timestamp;
    uint8 can_seek_to_end;
    uint8 have_keyframes;
    uint32 last_keyframe_timestamp;
    uint32 on_metadata_size;
    file_offset_t on_metadata_offset;
    uint32 biggest_tag_body_size;
    uint32 last_timestamp;
    uint32 video_frame_duration;
    uint32 audio_frame_duration;
    file_offset_t total_prev_tags_size;
    uint8 have_on_last_second;
    amf_data * original_on_metadata;
    amf_data * keyframes;
    amf_data * times;
    amf_data * filepositions;
} flv_info;

typedef struct __flv_metadata {
    amf_data * on_last_second_name;
    amf_data * on_last_second;
    amf_data * on_metadata_name;
    amf_data * on_metadata;
} flv_metadata;

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

int get_flv_info(flv_stream * flv_in, flv_info * info);

void compute_metadata(flv_info * info, flv_metadata * meta);

void compute_current_metadata(flv_info * info, flv_metadata * meta);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __INFO_H__ */
