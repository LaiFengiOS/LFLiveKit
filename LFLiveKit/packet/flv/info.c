/*
    $Id: info.c 231 2011-06-27 13:46:19Z marc.noirot $

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
#include "info.h"
#include "avc.h"

#include <string.h>

#pragma warning(disable:4244)
/*
    compute Sorensen H.263 video size
*/
static int compute_h263_size(flv_stream * flv_in, flv_info * info, uint32 body_length) {
    byte header[9];
    uint24_be psc_be;
    uint32 psc;

    /* make sure we have enough bytes to read in the current tag */
    if (body_length >= 9) {
        if (flv_read_tag_body(flv_in, header, 9) < 9) {
            return FLV_ERROR_EOF;
        }
        psc_be.b[0] = header[0];
        psc_be.b[1] = header[1];
        psc_be.b[2] = header[2];
        psc = uint24_be_to_uint32(psc_be) >> 7;
        if (psc == 1) {
            uint32 psize = ((header[3] & 0x03) << 1) + ((header[4] >> 7) & 0x01);
            switch (psize) {
                case 0:
                    info->video_width  = ((header[4] & 0x7f) << 1) + ((header[5] >> 7) & 0x01);
                    info->video_height = ((header[5] & 0x7f) << 1) + ((header[6] >> 7) & 0x01);
                    break;
                case 1:
                    info->video_width  = ((header[4] & 0x7f) << 9) + (header[5] << 1) + ((header[6] >> 7) & 0x01);
                    info->video_height = ((header[6] & 0x7f) << 9) + (header[7] << 1) + ((header[8] >> 7) & 0x01);
                    break;
                case 2:
                    info->video_width  = 352;
                    info->video_height = 288;
                    break;
                case 3:
                    info->video_width  = 176;
                    info->video_height = 144;
                    break;
                case 4:
                    info->video_width  = 128;
                    info->video_height = 96;
                    break;
                case 5:
                    info->video_width  = 320;
                    info->video_height = 240;
                    break;
                case 6:
                    info->video_width  = 160;
                    info->video_height = 120;
                    break;
                default:
                    break;
            }
        }
    }
    return FLV_OK;
}

/*
    compute Screen video size
*/
static int compute_screen_size(flv_stream * flv_in, flv_info * info, uint32 body_length) {
    byte header[4];

    /* make sure we have enough bytes to read in the current tag */
    if (body_length >= 4) {
        if (flv_read_tag_body(flv_in, header, 4) < 4) {
            return FLV_ERROR_EOF;
        }
        
        info->video_width  = ((header[0] & 0x0f) << 8) + header[1];
        info->video_height = ((header[2] & 0x0f) << 8) + header[3];
    }
    return FLV_OK;
}

/*
    compute On2 VP6 video size
*/
static int compute_vp6_size(flv_stream * flv_in, flv_info * info, uint32 body_length) {
    byte header[7], offset;

    /* make sure we have enough bytes to read in the current tag */
    if (body_length >= 7) {
        if (flv_read_tag_body(flv_in, header, 7) < 7) {
            return FLV_ERROR_EOF;
        }
        
        /* two bytes offset if VP6 0 */
        offset = (header[1] & 0x01 || !(header[2] & 0x06)) << 1;
        info->video_width  = (header[4 + offset] << 4) - (header[0] >> 4);
        info->video_height = (header[3 + offset] << 4) - (header[0] & 0x0f);
        
    }
    return FLV_OK;
}

/*
    compute On2 VP6 with Alpha video size
*/
static int compute_vp6_alpha_size(flv_stream * flv_in, flv_info * info, uint32 body_length) {
    byte header[10], offset;

    /* make sure we have enough bytes to read in the current tag */
    if (body_length >= 10) {
        if (flv_read_tag_body(flv_in, header, 10) < 10) {
            return FLV_ERROR_EOF;
        }
        
        /* two bytes offset if VP6 0 */
        offset = (header[4] & 0x01 || !(header[5] & 0x06)) << 1;
        info->video_width  = (header[7 + offset] << 4) - (header[0] >> 4);
        info->video_height = (header[6 + offset] << 4) - (header[0] & 0x0f);
    }
    return FLV_OK;
}

/*
    compute AVC (H.264) video size (experimental)
*/
static int compute_avc_size(flv_stream * flv_in, flv_info * info, uint32 body_length) {
    return read_avc_resolution(flv_in, body_length, &(info->video_width), &(info->video_height));
}

/*
    compute video width and height from the first video frame
*/
static int compute_video_size(flv_stream * flv_in, flv_info * info, uint32 body_length) {
    switch (info->video_codec) {
        case FLV_VIDEO_TAG_CODEC_SORENSEN_H263:
            return compute_h263_size(flv_in, info, body_length);
        case FLV_VIDEO_TAG_CODEC_SCREEN_VIDEO:
        case FLV_VIDEO_TAG_CODEC_SCREEN_VIDEO_V2:
            return compute_screen_size(flv_in, info, body_length);
        case FLV_VIDEO_TAG_CODEC_ON2_VP6:
            return compute_vp6_size(flv_in, info, body_length);
        case FLV_VIDEO_TAG_CODEC_ON2_VP6_ALPHA:
            return compute_vp6_alpha_size(flv_in, info, body_length);
        case FLV_VIDEO_TAG_CODEC_AVC:
            return compute_avc_size(flv_in, info, body_length);
        default:
            return FLV_OK;
    }
}

/*
    read the flv file thoroughly to get all necessary information.

    we need to check :
    - timestamp of first audio for audio delay
    - whether we have audio and video
    - first frames codecs (audio, video)
    - total audio and video data sizes
    - keyframe offsets and timestamps
    - whether the last video frame is a keyframe
    - last keyframe timestamp
    - onMetaData tag total size
    - total tags size
    - first tag after onMetaData offset
    - last timestamp
    - real video data size, number of frames, duration to compute framerate and video data rate
    - real audio data size, duration to compute audio data rate
    - video headers to find width and height. (depends on the encoding)
*/
int get_flv_info(flv_stream * flv_in, flv_info * info) {
    uint32 prev_timestamp_video;
    uint32 prev_timestamp_audio;
    uint32 prev_timestamp_meta;
    uint8 timestamp_extended_video;
    uint8 timestamp_extended_audio;
    uint8 timestamp_extended_meta;
    uint8 have_video_size;
    uint8 have_first_timestamp;
    uint32 tag_number;
    int result;
    flv_tag ft;

    info->have_video = 0;
    info->have_audio = 0;
    info->video_width = 0;
    info->video_height = 0;
    info->video_codec = 0;
    info->video_frames_number = 0;
    info->audio_codec = 0;
    info->audio_size = 0;
    info->audio_rate = 0;
    info->audio_stereo = 0;
    info->video_data_size = 0;
    info->audio_data_size = 0;
    info->meta_data_size = 0;
    info->real_video_data_size = 0;
    info->real_audio_data_size = 0;
    info->video_first_timestamp = 0;
    info->audio_first_timestamp = 0;
    info->first_timestamp = 0;
    info->can_seek_to_end = 0;
    info->have_keyframes = 0;
    info->last_keyframe_timestamp = 0;
    info->on_metadata_size = 0;
    info->on_metadata_offset = 0;
    info->biggest_tag_body_size = 0;
    info->last_timestamp = 0;
    info->video_frame_duration = 0;
    info->audio_frame_duration = 0;
    info->total_prev_tags_size = 0;
    info->have_on_last_second = 0;
    info->original_on_metadata = NULL;
    info->keyframes = NULL;
    info->times = NULL;
    info->filepositions = NULL;

    /*
        read FLV header
    */

    if (flv_read_header(flv_in, &(info->header)) != FLV_OK) {
        return FLV_ERROR_NO_FLV;
    }

    info->keyframes = amf_object_new();
    info->times = amf_array_new();
    info->filepositions = amf_array_new();
    amf_object_add(info->keyframes, "times", info->times);
    amf_object_add(info->keyframes, "filepositions", info->filepositions);

    /* first empty previous tag size */
    info->total_prev_tags_size = sizeof(uint32_be);

    /* first timestamp */
    have_first_timestamp = 0;

    /* extended timestamp initialization */
    prev_timestamp_video = 0;
    prev_timestamp_audio = 0;
    prev_timestamp_meta = 0;
    timestamp_extended_video = 0;
    timestamp_extended_audio = 0;
    timestamp_extended_meta = 0;
    tag_number = 0;
    have_video_size = 0;

    while (flv_read_tag(flv_in, &ft) == FLV_OK) {
        file_offset_t offset;
        uint32 body_length;
        uint32 timestamp;

        offset = flv_get_current_tag_offset(flv_in);
        body_length = flv_tag_get_body_length(ft);
        timestamp = flv_tag_get_timestamp(ft);

        /* extended timestamp fixing */
        if (ft.type == FLV_TAG_TYPE_META) {
            if (timestamp < prev_timestamp_meta
            && prev_timestamp_meta - timestamp > 0xF00000) {
                ++timestamp_extended_meta;
            }
            prev_timestamp_meta = timestamp;
            if (timestamp_extended_meta > 0) {
                timestamp += timestamp_extended_meta << 24;
            }
        }
        else if (ft.type == FLV_TAG_TYPE_AUDIO) {
            if (timestamp < prev_timestamp_audio
            && prev_timestamp_audio - timestamp > 0xF00000) {
                ++timestamp_extended_audio;
            }
            prev_timestamp_audio = timestamp;
            if (timestamp_extended_audio > 0) {
                timestamp += timestamp_extended_audio << 24;
            }
        }
        else if (ft.type == FLV_TAG_TYPE_VIDEO) {
            if (timestamp < prev_timestamp_video
            && prev_timestamp_video - timestamp > 0xF00000) {
                ++timestamp_extended_video;
            }
            prev_timestamp_video = timestamp;
            if (timestamp_extended_video > 0) {
                timestamp += timestamp_extended_video << 24;
            }
        }

        /* non-zero starting timestamp handling */
        if (!have_first_timestamp && ft.type != FLV_TAG_TYPE_META) {
            info->first_timestamp = timestamp;
            have_first_timestamp = 1;
        }
        if (timestamp > 0) {
            timestamp -= info->first_timestamp;
        }

        /* update the info struct only if the tag is valid */
        if (ft.type == FLV_TAG_TYPE_META
        || ft.type == FLV_TAG_TYPE_AUDIO
        || ft.type == FLV_TAG_TYPE_VIDEO) {
            if (info->biggest_tag_body_size < body_length) {
                info->biggest_tag_body_size = body_length;
            }
            info->last_timestamp = timestamp;
        }

        if (ft.type == FLV_TAG_TYPE_META) {
            amf_data *tag_name, *data;
            int retval;
            tag_name = data = NULL;

            if (body_length == 0) {
            } else {
                retval = flv_read_metadata(flv_in, &tag_name, &data);
                if (retval == FLV_ERROR_EOF) {
                    amf_data_free(tag_name);
                    amf_data_free(data);
                    return FLV_ERROR_EOF;
                } else if (retval == FLV_ERROR_INVALID_METADATA_NAME) {
                } else if (retval == FLV_ERROR_INVALID_METADATA) {
								}
            }

            /* check metadata name */
            if (body_length > 0 && amf_data_get_type(tag_name) == AMF_TYPE_STRING) {
                char * name = (char *)amf_string_get_bytes(tag_name);
                size_t len = (size_t)amf_string_get_size(tag_name);

                /* get info only on the first onMetaData we read */
                if (info->on_metadata_size == 0 && !strncmp(name, "onMetaData", len)) {
                    info->on_metadata_size = body_length + FLV_TAG_SIZE + sizeof(uint32_be);
                    info->on_metadata_offset = offset;

                    amf_data_free(data);
                }
                else {
                    if (!strncmp(name, "onLastSecond", len)) {
                        info->have_on_last_second = 1;
                    }
                    info->meta_data_size += (body_length + FLV_TAG_SIZE);
                    info->total_prev_tags_size += sizeof(uint32_be);
                    if (data != NULL) {
                        amf_data_free(data);
                    }
                }
            }
            /* just ignore metadata that don't have a proper name */
            else {
                info->meta_data_size += (body_length + FLV_TAG_SIZE);
                info->total_prev_tags_size += sizeof(uint32_be);
                amf_data_free(data);
            }
            amf_data_free(tag_name);
        }
        else if (ft.type == FLV_TAG_TYPE_VIDEO) {
            flv_video_tag vt;

            /* do not take video frame into account if body length is zero and we ignore errors */
            if (body_length == 0) {
            } else {
                if (flv_read_video_tag(flv_in, &vt) != FLV_OK) {
                    return FLV_ERROR_EOF;
                }

                if (info->have_video != 1) {
                    info->have_video = 1;
                    info->video_codec = flv_video_tag_codec_id(vt);
                    info->video_first_timestamp = timestamp;
                }

                if (have_video_size != 1
                && flv_video_tag_frame_type(vt) == FLV_VIDEO_TAG_FRAME_TYPE_KEYFRAME) {
                    /* read first video frame to get critical info */
                    result = compute_video_size(flv_in, info, body_length - sizeof(flv_video_tag));
                    if (result != FLV_OK) {
                        return result;
                    }

                    if (info->video_width > 0 && info->video_height > 0) {
                        have_video_size = 1;
                    }
                    /* if we cannot fetch that information from the first tag, we'll try
                       for each following video key frame */
                }

                /* add keyframe to list */
                if (flv_video_tag_frame_type(vt) == FLV_VIDEO_TAG_FRAME_TYPE_KEYFRAME) {
                    /* do not add keyframe if the previous one has the same timestamp */
                    if (!info->have_keyframes
                    || (info->have_keyframes && info->last_keyframe_timestamp != timestamp)) {
                        info->have_keyframes = 1;
                        info->last_keyframe_timestamp = timestamp;
                        amf_array_push(info->times, amf_number_new(timestamp / 1000.0));
                        amf_array_push(info->filepositions, amf_number_new((number64)offset));
                    }
                    /* is last frame a key frame ? if so, we can seek to end */
                    info->can_seek_to_end = 1;
                }
                else {
                    info->can_seek_to_end = 0;
                }

                info->real_video_data_size += (body_length - 1);    
            }

            info->video_frames_number++;

            /*
                we assume all video frames have the same size as the first one:
                probably bogus but only used in case there's no audio in the file
            */
            if (info->video_frame_duration == 0) {
                info->video_frame_duration = timestamp - info->video_first_timestamp;
            }

            info->video_data_size += (body_length + FLV_TAG_SIZE);
            info->total_prev_tags_size += sizeof(uint32_be);
        }
        else if (ft.type == FLV_TAG_TYPE_AUDIO) {
            flv_audio_tag at;

            /* do not take audio frame into account if body length is zero and we ignore errors */
            if (body_length == 0) {
            } else {
                if (flv_read_audio_tag(flv_in, &at) != FLV_OK) {
                    return FLV_ERROR_EOF;
                }
            
                if (info->have_audio != 1) {
                    info->have_audio = 1;
                    info->audio_codec = flv_audio_tag_sound_format(at);
                    info->audio_rate = flv_audio_tag_sound_rate(at);
                    info->audio_size = flv_audio_tag_sound_size(at);
                    info->audio_stereo = flv_audio_tag_sound_type(at);
                    info->audio_first_timestamp = timestamp;
                }
                /* we assume all audio frames have the same size as the first one */
                if (info->audio_frame_duration == 0) {
                    info->audio_frame_duration = timestamp - info->audio_first_timestamp;
                }

                info->real_audio_data_size += (body_length - 1);
            }
            
            info->audio_data_size += (body_length + FLV_TAG_SIZE);
            info->total_prev_tags_size += sizeof(uint32_be);
        }
        else {
           return 7;
        }
        ++tag_number;
    }

    return FLV_OK;
}

/*
    compute the metadata
*/
void compute_metadata(flv_info * info, flv_metadata * meta) {
    uint32 new_on_metadata_size, on_last_second_size;
    file_offset_t data_size, total_filesize;
    number64 duration, video_data_rate, framerate;
    amf_data * amf_total_filesize;
    amf_data * amf_total_data_size;
    amf_node * node_t;
    amf_node * node_f;

    meta->on_last_second_name = amf_str("onLastSecond");
    meta->on_last_second = amf_associative_array_new();
    meta->on_metadata_name = amf_str("onMetaData");
		meta->on_metadata = amf_associative_array_new();

    amf_associative_array_add(meta->on_metadata, "hasMetadata", amf_boolean_new(1));
    amf_associative_array_add(meta->on_metadata, "hasVideo", amf_boolean_new(info->have_video));
    amf_associative_array_add(meta->on_metadata, "hasAudio", amf_boolean_new(info->have_audio));
    
    if (info->have_audio) {
        duration = (info->last_timestamp - info->first_timestamp + info->audio_frame_duration) / 1000.0;
    }
    else {
        duration = (info->last_timestamp - info->first_timestamp + info->video_frame_duration) / 1000.0;
    }
    amf_associative_array_add(meta->on_metadata, "duration", amf_number_new(duration));

    amf_associative_array_add(meta->on_metadata, "lasttimestamp", amf_number_new(info->last_timestamp / 1000.0));
    amf_associative_array_add(meta->on_metadata, "lastkeyframetimestamp", amf_number_new(info->last_keyframe_timestamp / 1000.0));
    
    if (info->video_width > 0)
        amf_associative_array_add(meta->on_metadata, "width", amf_number_new(info->video_width));
    if (info->video_height > 0)
        amf_associative_array_add(meta->on_metadata, "height", amf_number_new(info->video_height));

    video_data_rate = ((info->real_video_data_size / 1024.0) * 8.0) / duration;
    amf_associative_array_add(meta->on_metadata, "videodatarate", amf_number_new(video_data_rate));

    framerate = info->video_frames_number / duration;
    amf_associative_array_add(meta->on_metadata, "framerate", amf_number_new(framerate));

    if (info->have_audio) {
        number64 audio_khz, audio_sample_rate;
        number64 audio_data_rate = ((info->real_audio_data_size / 1024.0) * 8.0) / duration;
        amf_associative_array_add(meta->on_metadata, "audiodatarate", amf_number_new(audio_data_rate));

        audio_khz = 0.0;
        switch (info->audio_rate) {
            case FLV_AUDIO_TAG_SOUND_RATE_5_5: audio_khz = 5500.0; break;
            case FLV_AUDIO_TAG_SOUND_RATE_11:  audio_khz = 11000.0; break;
            case FLV_AUDIO_TAG_SOUND_RATE_22:  audio_khz = 22050.0; break;
            case FLV_AUDIO_TAG_SOUND_RATE_44:  audio_khz = 44100.0; break;
        }
        amf_associative_array_add(meta->on_metadata, "audiosamplerate", amf_number_new(audio_khz));
        audio_sample_rate = 0.0;
        switch (info->audio_size) {
            case FLV_AUDIO_TAG_SOUND_SIZE_8:  audio_sample_rate = 8.0; break;
            case FLV_AUDIO_TAG_SOUND_SIZE_16: audio_sample_rate = 16.0; break;
        }
        amf_associative_array_add(meta->on_metadata, "audiosamplesize", amf_number_new(audio_sample_rate));
        amf_associative_array_add(meta->on_metadata, "stereo", amf_boolean_new(info->audio_stereo == FLV_AUDIO_TAG_SOUND_TYPE_STEREO));
    }

    /* to be computed later */
    amf_total_filesize = amf_number_new(0);
    amf_associative_array_add(meta->on_metadata, "filesize", amf_total_filesize);

    if (info->have_video) {
        amf_associative_array_add(meta->on_metadata, "videosize", amf_number_new((number64)info->video_data_size));
    }
    if (info->have_audio) {
        amf_associative_array_add(meta->on_metadata, "audiosize", amf_number_new((number64)info->audio_data_size));
    }

    /* to be computed later */
    amf_total_data_size = amf_number_new(0);
    amf_associative_array_add(meta->on_metadata, "datasize", amf_total_data_size);

    amf_associative_array_add(meta->on_metadata, "metadatacreator", amf_str("xingmeng"));

    amf_associative_array_add(meta->on_metadata, "metadatadate", amf_date_new((number64)time(NULL)*1000, 0));
    if (info->have_audio) {
        amf_associative_array_add(meta->on_metadata, "audiocodecid", amf_number_new((number64)info->audio_codec));
    }
    if (info->have_video) {
        amf_associative_array_add(meta->on_metadata, "videocodecid", amf_number_new((number64)info->video_codec));
    }
    if (info->have_audio && info->have_video) {
        number64 audio_delay = ((sint32)info->audio_first_timestamp - (sint32)info->video_first_timestamp) / 1000.0;
        amf_associative_array_add(meta->on_metadata, "audiodelay", amf_number_new((number64)audio_delay));
    }
    amf_associative_array_add(meta->on_metadata, "canSeekToEnd", amf_boolean_new(info->can_seek_to_end));
    
    /* only add empty cuepoints if we don't preserve existing tags OR if the existing tags don't have cuepoints */
    if ((amf_associative_array_get(info->original_on_metadata, "cuePoints") == NULL)) {
        amf_associative_array_add(meta->on_metadata, "hasCuePoints", amf_boolean_new(0));
        amf_associative_array_add(meta->on_metadata, "cuePoints", amf_array_new());
    }
    amf_associative_array_add(meta->on_metadata, "hasKeyframes", amf_boolean_new(info->have_keyframes));
    amf_associative_array_add(meta->on_metadata, "keyframes", info->keyframes);

    /*
        When we know the final size, we can recompute te offsets for the filepositions, and the final datasize.
    */
    new_on_metadata_size = FLV_TAG_SIZE + sizeof(uint32_be) +
        (uint32)(amf_data_size(meta->on_metadata_name) + amf_data_size(meta->on_metadata));
    on_last_second_size = (uint32)(amf_data_size(meta->on_last_second_name) + amf_data_size(meta->on_last_second));

    node_t = amf_array_first(info->times);
    node_f = amf_array_first(info->filepositions);
    while (node_t != NULL || node_f != NULL) {
        amf_data * amf_filepos = amf_array_get(node_f);
        number64 offset = amf_number_get_value(amf_filepos) + new_on_metadata_size - info->on_metadata_size;
        number64 timestamp = amf_number_get_value(amf_array_get(node_t));

        /* after the onLastSecond event we need to take in account the tag size */
        if (!info->have_on_last_second && (info->last_timestamp - timestamp * 1000) <= 1000) {
            offset += (FLV_TAG_SIZE + on_last_second_size + sizeof(uint32_be));
        }

        amf_number_set_value(amf_filepos, offset);
        node_t = amf_array_next(node_t);
        node_f = amf_array_next(node_f);
    }

    /* compute data size, ie. size of metadata excluding prev_tag_size */
    data_size = info->meta_data_size + FLV_TAG_SIZE +
        (uint32)(amf_data_size(meta->on_metadata_name) + amf_data_size(meta->on_metadata));
    if (!info->have_on_last_second) {
        data_size += (uint32)on_last_second_size + FLV_TAG_SIZE;
    }
    amf_number_set_value(amf_total_data_size, (number64)data_size);
  
    /* compute total file size */
    total_filesize = FLV_HEADER_SIZE + info->total_prev_tags_size + info->video_data_size +
        info->audio_data_size + info->meta_data_size + new_on_metadata_size;

    if (!info->have_on_last_second) {
        /* if we have to add onLastSecond, we must count the header and new prevTagSize we add */
        total_filesize += (uint32)(FLV_TAG_SIZE + on_last_second_size + sizeof(uint32_be));
    }

    amf_number_set_value(amf_total_filesize, (number64)total_filesize);
}


