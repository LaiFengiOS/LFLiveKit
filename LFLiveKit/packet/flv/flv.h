/*
    $Id: flv.h 231 2011-06-27 13:46:19Z marc.noirot $

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
#ifndef __FLV_H__
#define __FLV_H__

/* Configuration of the sources */
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "types.h"
#include "amf.h"

/* error statuses */
#define FLV_OK                          0
#define FLV_ERROR_OPEN_READ             1
#define FLV_ERROR_NO_FLV                2
#define FLV_ERROR_EOF                   3
#define FLV_ERROR_MEMORY                4
#define FLV_ERROR_EMPTY_TAG             5
#define FLV_ERROR_INVALID_METADATA_NAME 6
#define FLV_ERROR_INVALID_METADATA      7

/* flv file format structure and definitions */

/* FLV file header */
#define FLV_SIGNATURE       "FLV"
#define FLV_VERSION         ((uint8)0x01)

#define FLV_FLAG_VIDEO      ((uint8)0x01)
#define FLV_FLAG_AUDIO      ((uint8)0x04)

typedef struct __flv_header {
    byte            signature[3]; /* always "FLV" */
    uint8           version; /* should be 1 */
    uint8_bitmask   flags;
    uint32_be       offset; /* always 9 */
} flv_header;

#define FLV_HEADER_SIZE 9

#define flv_header_has_video(header)    ((header).flags & FLV_FLAG_VIDEO)
#define flv_header_has_audio(header)    ((header).flags & FLV_FLAG_AUDIO)
#define flv_header_get_offset(header)   (swap_uint32((header).offset))

/* FLV tag */
#define FLV_TAG_TYPE_AUDIO  ((uint8)0x08)
#define FLV_TAG_TYPE_VIDEO  ((uint8)0x09)
#define FLV_TAG_TYPE_META   ((uint8)0x12)

typedef struct __flv_tag {
    uint8       type;
    uint24_be   body_length; /* in bytes, total tag size minus 11 */
    uint24_be   timestamp; /* milli-seconds */
    uint8       timestamp_extended; /* timestamp extension */
    uint24_be   stream_id; /* reserved, must be "\0\0\0" */
    /* body comes next */
} flv_tag;

#define FLV_TAG_SIZE 11

#define flv_tag_get_body_length(tag)    (uint24_be_to_uint32((tag).body_length))
#define flv_tag_get_timestamp(tag) \
    (uint24_be_to_uint32((tag).timestamp) + ((tag).timestamp_extended << 24))
#define flv_tag_get_stream_id(tag)      (uint24_be_to_uint32((tag).stream_id))

/* audio tag */
#define FLV_AUDIO_TAG_SOUND_TYPE_MONO    0
#define FLV_AUDIO_TAG_SOUND_TYPE_STEREO  1

#define FLV_AUDIO_TAG_SOUND_SIZE_8       0
#define FLV_AUDIO_TAG_SOUND_SIZE_16      1

#define FLV_AUDIO_TAG_SOUND_RATE_5_5     0
#define FLV_AUDIO_TAG_SOUND_RATE_11      1
#define FLV_AUDIO_TAG_SOUND_RATE_22      2
#define FLV_AUDIO_TAG_SOUND_RATE_44      3

#define FLV_AUDIO_TAG_SOUND_FORMAT_LINEAR_PCM          0
#define FLV_AUDIO_TAG_SOUND_FORMAT_ADPCM               1
#define FLV_AUDIO_TAG_SOUND_FORMAT_MP3                 2
#define FLV_AUDIO_TAG_SOUND_FORMAT_LINEAR_PCM_LE       3
#define FLV_AUDIO_TAG_SOUND_FORMAT_NELLYMOSER_16_MONO  4
#define FLV_AUDIO_TAG_SOUND_FORMAT_NELLYMOSER_8_MONO   5
#define FLV_AUDIO_TAG_SOUND_FORMAT_NELLYMOSER          6
#define FLV_AUDIO_TAG_SOUND_FORMAT_G711_A              7
#define FLV_AUDIO_TAG_SOUND_FORMAT_G711_MU             8
#define FLV_AUDIO_TAG_SOUND_FORMAT_RESERVED            9
#define FLV_AUDIO_TAG_SOUND_FORMAT_AAC                 10
#define FLV_AUDIO_TAG_SOUND_FORMAT_SPEEX               11
#define FLV_AUDIO_TAG_SOUND_FORMAT_MP3_8               14
#define FLV_AUDIO_TAG_SOUND_FORMAT_DEVICE_SPECIFIC     15

typedef byte flv_audio_tag;

#define flv_audio_tag_sound_type(tag)   (((tag) & 0x01) >> 0)
#define flv_audio_tag_sound_size(tag)   (((tag) & 0x02) >> 1)
#define flv_audio_tag_sound_rate(tag)   (((tag) & 0x0C) >> 2)
#define flv_audio_tag_sound_format(tag) (((tag) & 0xF0) >> 4)

/* video tag */
#define FLV_VIDEO_TAG_CODEC_JPEG            1
#define FLV_VIDEO_TAG_CODEC_SORENSEN_H263   2
#define FLV_VIDEO_TAG_CODEC_SCREEN_VIDEO    3
#define FLV_VIDEO_TAG_CODEC_ON2_VP6         4
#define FLV_VIDEO_TAG_CODEC_ON2_VP6_ALPHA   5
#define FLV_VIDEO_TAG_CODEC_SCREEN_VIDEO_V2 6
#define FLV_VIDEO_TAG_CODEC_AVC             7

#define FLV_VIDEO_TAG_FRAME_TYPE_KEYFRAME               1
#define FLV_VIDEO_TAG_FRAME_TYPE_INTERFRAME             2
#define FLV_VIDEO_TAG_FRAME_TYPE_DISPOSABLE_INTERFRAME  3
#define FLV_VIDEO_TAG_FRAME_TYPE_GENERATED_KEYFRAME     4
#define FLV_VIDEO_TAG_FRAME_TYPE_COMMAND_FRAME          5

typedef byte flv_video_tag;

#define flv_video_tag_codec_id(tag)     (((tag) & 0x0F) >> 0)
#define flv_video_tag_frame_type(tag)   (((tag) & 0xF0) >> 4)

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/* FLV helper functions */
void flv_tag_set_timestamp(flv_tag * tag, uint32 timestamp);

/* FLV stream */
#define FLV_STREAM_STATE_START          0
#define FLV_STREAM_STATE_TAG            1
#define FLV_STREAM_STATE_TAG_BODY       2
#define FLV_STREAM_STATE_PREV_TAG_SIZE  3

typedef struct __flv_stream {
    FILE * flvin;
    uint8 state;
    flv_tag current_tag;
    file_offset_t current_tag_offset;
    uint32 current_tag_body_length;
    uint32 current_tag_body_overflow;
} flv_stream;

/* FLV stream functions */
flv_stream * flv_open(const char * file);
int flv_read_header(flv_stream * stream, flv_header * header);
int flv_read_prev_tag_size(flv_stream * stream, uint32 * prev_tag_size);
int flv_read_tag(flv_stream * stream, flv_tag * tag);
int flv_read_audio_tag(flv_stream * stream, flv_audio_tag * tag);
int flv_read_video_tag(flv_stream * stream, flv_video_tag * tag);
int flv_read_metadata(flv_stream * stream, amf_data ** name, amf_data ** data);
size_t flv_read_tag_body(flv_stream * stream, void * buffer, size_t buffer_size);
file_offset_t flv_get_current_tag_offset(flv_stream * stream);
file_offset_t flv_get_offset(flv_stream * stream);
void flv_reset(flv_stream * stream);
void flv_close(flv_stream * stream);

/* FLV stdio writing helper functions */
size_t flv_write_header(FILE * out, const flv_header * header);
size_t flv_write_tag(FILE * out, const flv_tag * tag);

/* FLV event based parser */
typedef struct __flv_parser {
    flv_stream * stream;
    void * user_data;
    int (* on_header)(flv_header * header, struct __flv_parser * parser);
    int (* on_tag)(flv_tag * tag, struct __flv_parser * parser);
    int (* on_metadata_tag)(flv_tag * tag, amf_data * name, amf_data * data, struct __flv_parser * parser);
    int (* on_audio_tag)(flv_tag * tag, flv_audio_tag audio_tag, struct __flv_parser * parser);
    int (* on_video_tag)(flv_tag * tag, flv_video_tag audio_tag, struct __flv_parser * parser);
    int (* on_unknown_tag)(flv_tag * tag, struct __flv_parser * parser);
    int (* on_prev_tag_size)(uint32 size, struct __flv_parser * parser);
    int (* on_stream_end)(struct __flv_parser * parser);
} flv_parser;

int flv_parse(const char * file, flv_parser * parser);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __FLV_H__ */
