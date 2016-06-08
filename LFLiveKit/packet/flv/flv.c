/*
    $Id: flv.c 231 2011-06-27 13:46:19Z marc.noirot $

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
#include "flv.h"

#include <string.h>

void flv_tag_set_timestamp(flv_tag * tag, uint32 timestamp) {
    tag->timestamp = uint32_to_uint24_be(timestamp);
    tag->timestamp_extended = (uint8)((timestamp & 0xFF000000) >> 24);
}

/* FLV stream functions */
flv_stream * flv_open(const char * file) {
    flv_stream * stream = (flv_stream *) malloc(sizeof(flv_stream));
    if (stream == NULL) {
        return NULL;
    }
    stream->flvin = fopen(file, "rb");
    if (stream->flvin == NULL) {
        free(stream);
        return NULL;
    }
    stream->current_tag_body_length = 0;
    stream->current_tag_body_overflow = 0;
    stream->current_tag_offset = 0;
    stream->state = FLV_STREAM_STATE_START;
    return stream;
}

int flv_read_header(flv_stream * stream, flv_header * header) {
    if (stream == NULL
    || stream->flvin == NULL
    || feof(stream->flvin)
    || stream->state != FLV_STREAM_STATE_START) {
        return FLV_ERROR_EOF;
    }

    if (fread(&header->signature, sizeof(header->signature), 1, stream->flvin) == 0
    || fread(&header->version, sizeof(header->version), 1, stream->flvin) == 0
    || fread(&header->flags, sizeof(header->flags), 1, stream->flvin) == 0
    || fread(&header->offset, sizeof(header->offset), 1, stream->flvin) == 0) {
        return FLV_ERROR_EOF;
    }

    if (header->signature[0] != 'F'
    || header->signature[1] != 'L'
    || header->signature[2] != 'V') {
        return FLV_ERROR_NO_FLV;
    }
    
    stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
    return FLV_OK;
}

int flv_read_prev_tag_size(flv_stream * stream, uint32 * prev_tag_size) {
    uint32_be val;
    if (stream == NULL
    || stream->flvin == NULL
    || feof(stream->flvin)) {
        return FLV_ERROR_EOF;
    }

    /* skip remaining tag body bytes */
    if (stream->state == FLV_STREAM_STATE_TAG_BODY) {
        lfs_fseek(stream->flvin, stream->current_tag_offset + FLV_TAG_SIZE + uint24_be_to_uint32(stream->current_tag.body_length), SEEK_SET);
        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
    }

    if (stream->state == FLV_STREAM_STATE_PREV_TAG_SIZE) {
        if (fread(&val, sizeof(uint32_be), 1, stream->flvin) == 0) {
            return FLV_ERROR_EOF;
        }
        else {
            stream->state = FLV_STREAM_STATE_TAG;
            *prev_tag_size = swap_uint32(val);
            return FLV_OK;
        }
    }
    else {
        return FLV_ERROR_EOF;
    }
}

int flv_read_tag(flv_stream * stream, flv_tag * tag) {
    if (stream == NULL
    || stream->flvin == NULL
    || feof(stream->flvin)) {
        return FLV_ERROR_EOF;
    }

    /* skip header */
    if (stream->state == FLV_STREAM_STATE_START) {
        lfs_fseek(stream->flvin, FLV_HEADER_SIZE, SEEK_CUR);
        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
    }

    /* skip current tag body */
    if (stream->state == FLV_STREAM_STATE_TAG_BODY) {
        lfs_fseek(stream->flvin, stream->current_tag_offset + FLV_TAG_SIZE + uint24_be_to_uint32(stream->current_tag.body_length), SEEK_SET);
        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
    }
 
    /* skip previous tag size */
    if (stream->state == FLV_STREAM_STATE_PREV_TAG_SIZE) {
        lfs_fseek(stream->flvin, sizeof(uint32_be), SEEK_CUR);
        stream->state = FLV_STREAM_STATE_TAG;
    }
    
    if (stream->state == FLV_STREAM_STATE_TAG) {
        stream->current_tag_offset = lfs_ftell(stream->flvin);

        if (fread(&tag->type, sizeof(tag->type), 1, stream->flvin) == 0
        || fread(&tag->body_length, sizeof(tag->body_length), 1, stream->flvin) == 0
        || fread(&tag->timestamp, sizeof(tag->timestamp), 1, stream->flvin) == 0
        || fread(&tag->timestamp_extended, sizeof(tag->timestamp_extended), 1, stream->flvin) == 0
        || fread(&tag->stream_id, sizeof(tag->stream_id), 1, stream->flvin) == 0) {
            return FLV_ERROR_EOF;
        }
        else {
            memcpy(&stream->current_tag, tag, sizeof(flv_tag));
            stream->current_tag_body_length = uint24_be_to_uint32(tag->body_length);
            stream->current_tag_body_overflow = 0;
            stream->state = FLV_STREAM_STATE_TAG_BODY;
            return FLV_OK;
        }
    }
    else {
        return FLV_ERROR_EOF;
    }
}

int flv_read_audio_tag(flv_stream * stream, flv_audio_tag * tag) {
    if (stream == NULL
    || stream->flvin == NULL
    || feof(stream->flvin)
    || stream->state != FLV_STREAM_STATE_TAG_BODY) {
        return FLV_ERROR_EOF;
    }

    if (stream->current_tag_body_length == 0) {
        return FLV_ERROR_EMPTY_TAG;
    }

    if (fread(tag, sizeof(flv_audio_tag), 1, stream->flvin) == 0) {
        return FLV_ERROR_EOF;
    }
    
    if (stream->current_tag_body_length >= sizeof(flv_audio_tag)) {
        stream->current_tag_body_length -= sizeof(flv_audio_tag);
    }
    else {
        stream->current_tag_body_overflow = sizeof(flv_audio_tag) - stream->current_tag_body_length;
        stream->current_tag_body_length = 0;
    }

    if (stream->current_tag_body_length == 0) {
        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
        if (stream->current_tag_body_overflow > 0) {
            lfs_fseek(stream->flvin, -(file_offset_t)stream->current_tag_body_overflow, SEEK_CUR);
        }
    }

    return FLV_OK;
}

int flv_read_video_tag(flv_stream * stream, flv_video_tag * tag) {
    if (stream == NULL
    || stream->flvin == NULL
    || feof(stream->flvin)
    || stream->state != FLV_STREAM_STATE_TAG_BODY) {
        return FLV_ERROR_EOF;
    }

    if (stream->current_tag_body_length == 0) {
        return FLV_ERROR_EMPTY_TAG;
    }

    if (fread(tag, sizeof(flv_video_tag), 1, stream->flvin) == 0) {
        return FLV_ERROR_EOF;
    }

    if (stream->current_tag_body_length >= sizeof(flv_video_tag)) {
        stream->current_tag_body_length -= sizeof(flv_video_tag);
    }
    else {
        stream->current_tag_body_overflow = sizeof(flv_video_tag) - stream->current_tag_body_length;
        stream->current_tag_body_length = 0;
    }

    if (stream->current_tag_body_length == 0) {
        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
        if (stream->current_tag_body_overflow > 0) {
            lfs_fseek(stream->flvin, -(file_offset_t)stream->current_tag_body_overflow, SEEK_CUR);
        }
    }

    return FLV_OK;
}

int flv_read_metadata(flv_stream * stream, amf_data ** name, amf_data ** data) {
    amf_data * d;
    byte error_code;
    size_t data_size;

    if (stream == NULL
    || stream->flvin == NULL
    || feof(stream->flvin)
    || stream->state != FLV_STREAM_STATE_TAG_BODY) {
        return FLV_ERROR_EOF;
    }

    if (stream->current_tag_body_length == 0) {
        return FLV_ERROR_EMPTY_TAG;
    }
    
    /* read metadata name */
    d = amf_data_file_read(stream->flvin);
    *name = d;
    error_code = amf_data_get_error_code(d);
    if (error_code == AMF_ERROR_EOF) {
        return FLV_ERROR_EOF;
    }
    else if (error_code != AMF_ERROR_OK) {
        return FLV_ERROR_INVALID_METADATA_NAME;
    }
    
    /* if only name can be read, metadata are invalid */
    data_size = amf_data_size(d);
    if (stream->current_tag_body_length > data_size) {
        stream->current_tag_body_length -= (uint32)data_size;
    }
    else {
        stream->current_tag_body_length = 0;
        stream->current_tag_body_overflow = (uint32)data_size - stream->current_tag_body_length;

        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
        if (stream->current_tag_body_overflow > 0) {
            lfs_fseek(stream->flvin, -(file_offset_t)stream->current_tag_body_overflow, SEEK_CUR);
        }

        return FLV_ERROR_INVALID_METADATA;
    }
    
    /* read metadata contents */
    d = amf_data_file_read(stream->flvin);
    *data = d;
    error_code = amf_data_get_error_code(d);
    if (error_code == AMF_ERROR_EOF) {
        return FLV_ERROR_EOF;
    }
    if (error_code != AMF_ERROR_OK) {
        return FLV_ERROR_INVALID_METADATA;
    }
    
    data_size = amf_data_size(d);
    if (stream->current_tag_body_length >= data_size) {
        stream->current_tag_body_length -= (uint32)data_size;
    }
    else {
        stream->current_tag_body_overflow = (uint32)data_size - stream->current_tag_body_length;
        stream->current_tag_body_length = 0;
    }

    if (stream->current_tag_body_length == 0) {
        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
        if (stream->current_tag_body_overflow > 0) {
            lfs_fseek(stream->flvin, -(file_offset_t)stream->current_tag_body_overflow, SEEK_CUR);
        }
    }

    return FLV_OK;
}

size_t flv_read_tag_body(flv_stream * stream, void * buffer, size_t buffer_size) {
    size_t bytes_number;

    if (stream == NULL
    || stream->flvin == NULL
    || feof(stream->flvin)
    || stream->state != FLV_STREAM_STATE_TAG_BODY) {
        return 0;
    }

    bytes_number = (buffer_size > stream->current_tag_body_length) ? stream->current_tag_body_length : buffer_size;
    bytes_number = fread(buffer, sizeof(byte), bytes_number, stream->flvin);
    
    stream->current_tag_body_length -= (uint32)bytes_number;

    if (stream->current_tag_body_length == 0) {
        stream->state = FLV_STREAM_STATE_PREV_TAG_SIZE;
    }

    return bytes_number;
}

file_offset_t flv_get_current_tag_offset(flv_stream * stream) {
    return (stream != NULL) ? stream->current_tag_offset : 0;
}

file_offset_t flv_get_offset(flv_stream * stream) {
    return (stream != NULL) ? lfs_ftell(stream->flvin) : 0;
}

void flv_reset(flv_stream * stream) {
    /* go back to beginning of file */
    if (stream != NULL && stream->flvin != NULL) {
        stream->current_tag_body_length = 0;
        stream->current_tag_offset = 0;
        stream->state = FLV_STREAM_STATE_START;

        lfs_fseek(stream->flvin, 0, SEEK_SET);
    }
}

void flv_close(flv_stream * stream) {
    if (stream != NULL) {
        if (stream->flvin != NULL) {
            fclose(stream->flvin);
        }
        free(stream);
    }
}

/* FLV stdio writing helper functions */
size_t flv_write_header(FILE * out, const flv_header * header) {
    if (fwrite(&header->signature, sizeof(header->signature), 1, out) == 0)
        return 0;
    if (fwrite(&header->version, sizeof(header->version), 1, out) == 0)
        return 0;
    if (fwrite(&header->flags, sizeof(header->flags), 1, out) == 0)
        return 0;
    if (fwrite(&header->offset, sizeof(header->offset), 1, out) == 0)
        return 0;
    return 1;
}

size_t flv_write_tag(FILE * out, const flv_tag * tag) {
    if (fwrite(&tag->type, sizeof(tag->type), 1, out) == 0)
        return 0;

    if (fwrite(&tag->body_length, sizeof(tag->body_length), 1, out) == 0)
        return 0;

    if (fwrite(&tag->timestamp, sizeof(tag->timestamp), 1, out) == 0)
        return 0;
    if (fwrite(&tag->timestamp_extended, sizeof(tag->timestamp_extended), 1, out) == 0)
        return 0;
    if (fwrite(&tag->stream_id, sizeof(tag->stream_id), 1, out) == 0)
        return 0;
    return 1;
}

/* FLV event based parser */
int flv_parse(const char * file, flv_parser * parser) {
    flv_header header;
    flv_tag tag;
    flv_audio_tag at;
    flv_video_tag vt;
    amf_data * name, * data;
    uint32 prev_tag_size;
    int retval;

    if (parser == NULL) {
        return FLV_ERROR_EOF;
    }

    parser->stream = flv_open(file);
    if (parser->stream == NULL) {
        return FLV_ERROR_OPEN_READ;
    }

    retval = flv_read_header(parser->stream, &header);
    if (retval != FLV_OK) {
        flv_close(parser->stream);
        return retval;
    }

    if (parser->on_header != NULL) {
        retval = parser->on_header(&header, parser);
        if (retval != FLV_OK) {
            flv_close(parser->stream);
            return retval;
        }
    }

    while (flv_read_tag(parser->stream, &tag) == FLV_OK) {
        if (parser->on_tag != NULL) {
            retval = parser->on_tag(&tag, parser);
            if (retval != FLV_OK) {
                flv_close(parser->stream);
                return retval;
            }
        }

        if (tag.type == FLV_TAG_TYPE_AUDIO) {
            retval = flv_read_audio_tag(parser->stream, &at);
            if (retval == FLV_ERROR_EOF) {
                flv_close(parser->stream);
                return retval;
            }
            if (retval != FLV_ERROR_EMPTY_TAG && parser->on_audio_tag != NULL) {
                retval = parser->on_audio_tag(&tag, at, parser);
                if (retval != FLV_OK) {
                    flv_close(parser->stream);
                    return retval;
                }
            }
        }
        else if (tag.type == FLV_TAG_TYPE_VIDEO) {
            retval = flv_read_video_tag(parser->stream, &vt);
            if (retval == FLV_ERROR_EOF) {
                flv_close(parser->stream);
                return retval;
            }
            if (retval != FLV_ERROR_EMPTY_TAG && parser->on_video_tag != NULL) {
                retval = parser->on_video_tag(&tag, vt, parser);
                if (retval != FLV_OK) {
                    flv_close(parser->stream);
                    return retval;
                }
            }
        }
        else if (tag.type == FLV_TAG_TYPE_META) {
            name = data = NULL;
            retval = flv_read_metadata(parser->stream, &name, &data);
            if (retval == FLV_ERROR_EOF) {
                amf_data_free(name);
                amf_data_free(data);
                flv_close(parser->stream);
                return retval;
            }
            else if (retval == FLV_OK && parser->on_metadata_tag != NULL) {
                retval = parser->on_metadata_tag(&tag, name, data, parser);
                if (retval != FLV_OK) {
                    amf_data_free(name);
                    amf_data_free(data);
                    flv_close(parser->stream);
                    return retval;
                }
            }
            amf_data_free(name);
            amf_data_free(data);
        }
        else {
            if (parser->on_unknown_tag != NULL) {
                retval = parser->on_unknown_tag(&tag, parser);
                if (retval != FLV_OK) {
                    flv_close(parser->stream);
                    return retval;
                }
            }
        }
        retval = flv_read_prev_tag_size(parser->stream, &prev_tag_size);
        if (retval != FLV_OK) {
            flv_close(parser->stream);
            return retval;
        }
        if (parser->on_prev_tag_size != NULL) {
            retval = parser->on_prev_tag_size(prev_tag_size, parser);
            if (retval != FLV_OK) {
                flv_close(parser->stream);
                return retval;
            }
        }
    }
    
    if (parser->on_stream_end != NULL) {
        retval = parser->on_stream_end(parser);
        if (retval != FLV_OK) {
            flv_close(parser->stream);
            return retval;
        }
    }

    flv_close(parser->stream);
    return FLV_OK;
}
