/*
    $Id: amf.h 231 2011-06-27 13:46:19Z marc.noirot $

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
#ifndef __AMF_H__
#define __AMF_H__

#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#include "types.h"

/* AMF data types */
#define AMF_TYPE_NUMBER             ((byte)0x00)
#define AMF_TYPE_BOOLEAN	        ((byte)0x01)
#define AMF_TYPE_STRING	            ((byte)0x02)
#define AMF_TYPE_OBJECT	            ((byte)0x03)
#define AMF_TYPE_NULL               ((byte)0x05)
#define AMF_TYPE_UNDEFINED	        ((byte)0x06)
/* #define AMF_TYPE_REFERENCE	    ((byte)0x07) */
#define AMF_TYPE_ASSOCIATIVE_ARRAY	((byte)0x08)
#define AMF_TYPE_END                ((byte)0x09)
#define AMF_TYPE_ARRAY	            ((byte)0x0A)
#define AMF_TYPE_DATE	            ((byte)0x0B)
/* #define AMF_TYPE_SIMPLEOBJECT	((byte)0x0D) */
#define AMF_TYPE_XML	            ((byte)0x0F)
#define AMF_TYPE_CLASS	            ((byte)0x10)

/* AMF error codes */
#define AMF_ERROR_OK                ((byte)0x00)
#define AMF_ERROR_EOF               ((byte)0x01)
#define AMF_ERROR_UNKNOWN_TYPE      ((byte)0x02)
#define AMF_ERROR_END_TAG           ((byte)0x03)
#define AMF_ERROR_NULL_POINTER      ((byte)0x04)
#define AMF_ERROR_MEMORY            ((byte)0x05)
#define AMF_ERROR_UNSUPPORTED_TYPE  ((byte)0x06)

typedef struct __amf_node * p_amf_node;

/* string type */
typedef struct __amf_string {
    uint16 size;
    byte * mbstr;
} amf_string;

/* array type */
typedef struct __amf_list {
    uint32 size;
    p_amf_node first_element;
    p_amf_node last_element;
} amf_list;

/* date type */
typedef struct __amf_date {
    number64 milliseconds;
    sint16 timezone;
} amf_date;

/* XML string type */
typedef struct __amf_xmlstring {
    uint32 size;
    byte * mbstr;
} amf_xmlstring;

/* class type */
typedef struct __amf_class {
    amf_string name;
    amf_list elements;
} amf_class;

/* structure encapsulating the various AMF objects */
typedef struct __amf_data {
    byte type;
    byte error_code;
    union {
        number64 number_data;
        uint8 boolean_data;
        amf_string string_data;
        amf_list list_data;
        amf_date date_data;
        amf_xmlstring xmlstring_data;
        amf_class class_data;
    };
} amf_data;

/* node used in lists, relies on amf_data */
typedef struct __amf_node {
    amf_data * data;
    p_amf_node prev;
    p_amf_node next;
} amf_node;

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/* Pluggable backend support */
typedef size_t (*amf_read_proc)(void * out_buffer, size_t size, void * user_data);
typedef size_t (*amf_write_proc)(const void * in_buffer, size_t size, void * user_data);

/* read AMF data */
amf_data * amf_data_read(amf_read_proc read_proc, void * user_data);

/* write AMF data */
size_t amf_data_write(const amf_data * data, amf_write_proc write_proc, void * user_data);

/* generic functions */

/* allocate an AMF data object */
amf_data * amf_data_new(byte type);
/* load AMF data from buffer */
amf_data * amf_data_buffer_read(byte * buffer, size_t maxbytes);
/* load AMF data from stream */
amf_data * amf_data_file_read(FILE * stream);
/* AMF data size */
size_t     amf_data_size(const amf_data * data);
/* write encoded AMF data into a buffer */
size_t     amf_data_buffer_write(amf_data * data, byte * buffer, size_t maxbytes);
/* write encoded AMF data into a stream */
size_t     amf_data_file_write(const amf_data * data, FILE * stream);
/* get the type of AMF data */
byte       amf_data_get_type(const amf_data * data);
/* get the error code of AMF data */
byte       amf_data_get_error_code(const amf_data * data);
/* return a new copy of AMF data */
amf_data * amf_data_clone(const amf_data * data);
/* release the memory of AMF data */
void       amf_data_free(amf_data * data);
/* dump AMF data into a stream as text */
void       amf_data_dump(FILE * stream, const amf_data * data, int indent_level);

/* return a null AMF object with the specified error code attached to it */
amf_data * amf_data_error(byte error_code);

/* number functions */
amf_data * amf_number_new(number64 value);
amf_data * amf_number_double(double value);
number64   amf_number_get_value(const amf_data * data);
void       amf_number_set_value(amf_data * data, number64 value);

/* boolean functions */
amf_data * amf_boolean_new(uint8 value);
uint8      amf_boolean_get_value(const amf_data * data);
void       amf_boolean_set_value(amf_data * data, uint8 value);

/* string functions */
amf_data * amf_string_new(byte * str, uint16 size);
amf_data * amf_str(const char * str);
uint16     amf_string_get_size(const amf_data * data);
byte *     amf_string_get_bytes(const amf_data * data);

/* object functions */
amf_data * amf_object_new(void);
uint32     amf_object_size(const amf_data * data);
amf_data * amf_object_add(amf_data * data, const char * name, amf_data * element);
amf_data * amf_object_get(const amf_data * data, const char * name);
amf_data * amf_object_set(amf_data * data, const char * name, amf_data * element);
amf_data * amf_object_delete(amf_data * data, const char * name);
amf_node * amf_object_first(const amf_data * data);
amf_node * amf_object_last(const amf_data * data);
amf_node * amf_object_next(amf_node * node);
amf_node * amf_object_prev(amf_node * node);
amf_data * amf_object_get_name(amf_node * node);
amf_data * amf_object_get_data(amf_node * node);

/* null functions */
#define amf_null_new() amf_data_new(AMF_TYPE_NULL)

/* undefined functions */
#define amf_undefined_new() amf_data_new(AMF_TYPE_UNDEFINED)

/* associative array functions */
amf_data * amf_associative_array_new(void);
#define amf_associative_array_size(d)       amf_object_size(d)
#define amf_associative_array_add(d, n, e)  amf_object_add(d, n, e)
#define amf_associative_array_get(d, n)     amf_object_get(d, n)
#define amf_associative_array_set(d, n, e)  amf_object_set(d, n, e)
#define amf_associative_array_delete(d, n)  amf_object_delete(d, n)
#define amf_associative_array_first(d)      amf_object_first(d)
#define amf_associative_array_last(d)       amf_object_last(d)
#define amf_associative_array_next(n)       amf_object_next(n)
#define amf_associative_array_prev(n)       amf_object_prev(n)
#define amf_associative_array_get_name(n)   amf_object_get_name(n)
#define amf_associative_array_get_data(n)   amf_object_get_data(n)

/* array functions */
amf_data * amf_array_new(void);
uint32     amf_array_size(const amf_data * data);
amf_data * amf_array_push(amf_data * data, amf_data * element);
amf_data * amf_array_pop(amf_data * data);
amf_node * amf_array_first(const amf_data * data);
amf_node * amf_array_last(const amf_data * data);
amf_node * amf_array_next(amf_node * node);
amf_node * amf_array_prev(amf_node * node);
amf_data * amf_array_get(amf_node * node);
amf_data * amf_array_get_at(const amf_data * data, uint32 n);
amf_data * amf_array_delete(amf_data * data, amf_node * node);
amf_data * amf_array_insert_before(amf_data * data, amf_node * node, amf_data * element);
amf_data * amf_array_insert_after(amf_data * data, amf_node * node, amf_data * element);

/* date functions */
amf_data * amf_date_new(number64 milliseconds, sint16 timezone);
number64   amf_date_get_milliseconds(const amf_data * data);
sint16     amf_date_get_timezone(const amf_data * data);
time_t     amf_date_to_time_t(const amf_data * data);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* __AMF_H__ */
