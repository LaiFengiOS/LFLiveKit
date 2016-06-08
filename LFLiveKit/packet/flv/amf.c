/*
    $Id: amf.c 231 2011-06-27 13:46:19Z marc.noirot $

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
#include <string.h>

#include "amf.h"

/* function common to all array types */
static void amf_list_init(amf_list * list) {
    if (list != NULL) {
        list->size = 0;
        list->first_element = NULL;
        list->last_element = NULL;
    }
}

static amf_data * amf_list_push(amf_list * list, amf_data * data) {
    amf_node * node = (amf_node*)malloc(sizeof(amf_node));
    if (node != NULL) {
        node->data = data;
        node->next = NULL;
        node->prev = NULL;
        if (list->size == 0) {
            list->first_element = node;
            list->last_element = node;
        }
        else {
            list->last_element->next = node;
            node->prev = list->last_element;
            list->last_element = node;
        }
        ++(list->size);
        return data;
    }
    return NULL;
}

static amf_data * amf_list_insert_before(amf_list * list, amf_node * node, amf_data * data) {
    if (node != NULL) {
        amf_node * new_node = (amf_node*)malloc(sizeof(amf_node));
        if (new_node != NULL) {
            new_node->next = node;
            new_node->prev = node->prev;

            if (node->prev != NULL) {
                node->prev->next = new_node;
                node->prev = new_node;
            }
            if (node == list->first_element) {
                list->first_element = new_node;
            }
            ++(list->size);
            new_node->data = data;
            return data;
        }
    }
    return NULL;
}

static amf_data * amf_list_insert_after(amf_list * list, amf_node * node, amf_data * data) {
    if (node != NULL) {
        amf_node * new_node = (amf_node*)malloc(sizeof(amf_node));
        if (new_node != NULL) {
            new_node->next = node->next;
            new_node->prev = node;

            if (node->next != NULL) {
                node->next->prev = new_node;
                node->next = new_node;
            }
            if (node == list->last_element) {
                list->last_element = new_node;
            }
            ++(list->size);
            new_node->data = data;
            return data;
        }
    }
    return NULL;
}

static amf_data * amf_list_delete(amf_list * list, amf_node * node) {
    amf_data * data = NULL;
    if (node != NULL) {
        if (node->next != NULL) {
            node->next->prev = node->prev;
        }
        if (node->prev != NULL) {
            node->prev->next = node->next;
        }
        if (node == list->first_element) {
            list->first_element = node->next;
        }
        if (node == list->last_element) {
            list->last_element = node->prev;
        }
        data = node->data;
        free(node);
        --(list->size);
    }
    return data;
}

static amf_data * amf_list_get_at(const amf_list * list, uint32 n) {
    if (n < list->size) {
        uint32 i;
        amf_node * node = list->first_element;
        for (i = 0; i < n; ++i) {
            node = node->next;
        }
        return node->data;
    }
    return NULL;
}

static amf_data * amf_list_pop(amf_list * list) {
    return amf_list_delete(list, list->last_element);
}

static amf_node * amf_list_first(const amf_list * list) {
    return list->first_element;
}

static amf_node * amf_list_last(const amf_list * list) {
    return list->last_element;
}

static void amf_list_clear(amf_list * list) {
    amf_node * tmp;
    amf_node * node = list->first_element;
    while (node != NULL) {
        amf_data_free(node->data);
        tmp = node;
        node = node->next;
        free(tmp);
    }
    list->size = 0;
}

static amf_list * amf_list_clone(const amf_list * list, amf_list * out_list) {
    amf_node * node;
    node = list->first_element;
    while (node != NULL) {
        amf_list_push(out_list, amf_data_clone(node->data));
        node = node->next;
    }
    return out_list;
}

/* structure used to mimic a stream with a memory buffer */
typedef struct __buffer_context {
    byte * start_address;
    byte * current_address;
    size_t buffer_size;
} buffer_context;

/* callback function to mimic fread using a memory buffer */
static size_t buffer_read(void * out_buffer, size_t size, void * user_data) {
    buffer_context * ctxt = (buffer_context *)user_data;
    if (ctxt->current_address >= ctxt->start_address &&
        ctxt->current_address + size <= ctxt->start_address + ctxt->buffer_size) {

        memcpy(out_buffer, ctxt->current_address, size);
        ctxt->current_address += size;
        return size;
    }
    else {
        return 0;
    }
}

/* callback function to mimic fwrite using a memory buffer */
static size_t buffer_write(const void * in_buffer, size_t size, void * user_data) {
    buffer_context * ctxt = (buffer_context *)user_data;
    if (ctxt->current_address >= ctxt->start_address &&
        ctxt->current_address + size <= ctxt->start_address + ctxt->buffer_size) {

        memcpy(ctxt->current_address, in_buffer, size);
        ctxt->current_address += size;
        return size;
    }
    else {
        return 0;
    }
}

/* allocate an AMF data object */
amf_data * amf_data_new(byte type) {
    amf_data * data = (amf_data*)malloc(sizeof(amf_data));
    if (data != NULL) {
        data->type = type;
        data->error_code = AMF_ERROR_OK;
    }
    return data;
}

/* read AMF data from buffer */
amf_data * amf_data_buffer_read(byte * buffer, size_t maxbytes) {
    buffer_context ctxt;
    ctxt.start_address = ctxt.current_address = buffer;
    ctxt.buffer_size = maxbytes;
    return amf_data_read(buffer_read, &ctxt);
}

/* write AMF data to buffer */
size_t amf_data_buffer_write(amf_data * data, byte * buffer, size_t maxbytes) {
    buffer_context ctxt;
    ctxt.start_address = ctxt.current_address = buffer;
    ctxt.buffer_size = maxbytes;
    return amf_data_write(data, buffer_write, &ctxt);
}

/* callback function to read data from a file stream */
static size_t file_read(void * out_buffer, size_t size, void * user_data) {
    return fread(out_buffer, sizeof(byte), size, (FILE *)user_data);
}

/* callback function to write data to a file stream */
static size_t file_write(const void * in_buffer, size_t size, void * user_data) {
    return fwrite(in_buffer, sizeof(byte), size, (FILE *)user_data);
}

/* load AMF data from a file stream */
amf_data * amf_data_file_read(FILE * stream) {
    return amf_data_read(file_read, stream);
}

/* write AMF data into a file stream */
size_t amf_data_file_write(const amf_data * data, FILE * stream) {
    return amf_data_write(data, file_write, stream);
}

/* read a number */
static amf_data * amf_number_read(amf_read_proc read_proc, void * user_data) {
    number64_be val;
    if (read_proc(&val, sizeof(number64_be), user_data) == sizeof(number64_be)) {
        return amf_number_new(swap_number64(val));
    }
    else {
        return amf_data_error(AMF_ERROR_EOF);
    }
}

/* read a boolean */
static amf_data * amf_boolean_read(amf_read_proc read_proc, void * user_data) {
    uint8 val;
    if (read_proc(&val, sizeof(uint8), user_data) == sizeof(uint8)) {
        return amf_boolean_new(val);
    }
    else {
        return amf_data_error(AMF_ERROR_EOF);
    }
}

/* read a string */
static amf_data * amf_string_read(amf_read_proc read_proc, void * user_data) {
    uint16_be strsize;
    byte * buffer;
    
    if (read_proc(&strsize, sizeof(uint16_be), user_data) < sizeof(uint16_be)) {
        return amf_data_error(AMF_ERROR_EOF);
    }
        
    strsize = swap_uint16(strsize);
    if (strsize == 0) {
        return amf_string_new(NULL, 0);
    }

    buffer = (byte*)calloc(strsize, sizeof(byte));
    if (buffer == NULL) {
        return NULL;
    }

    if (read_proc(buffer, strsize, user_data) == strsize) {
        amf_data * data = amf_string_new(buffer, strsize);
        free(buffer);
        return data;
    }
    else {
        free(buffer);
        return amf_data_error(AMF_ERROR_EOF);
    }
}

/* read an object */
static amf_data * amf_object_read(amf_read_proc read_proc, void * user_data) {
    amf_data * name;
    amf_data * element;
    byte error_code;
    amf_data * data;
    
    data = amf_object_new();
    if (data == NULL) {
        return NULL;
    }

    while (1) {
        name = amf_string_read(read_proc, user_data);
        error_code = amf_data_get_error_code(name);
        if (error_code != AMF_ERROR_OK) {
            /* invalid name: error */
            amf_data_free(name);
            amf_data_free(data);
            return amf_data_error(error_code);
        }

        element = amf_data_read(read_proc, user_data);
        error_code = amf_data_get_error_code(element);
        if (error_code == AMF_ERROR_END_TAG || error_code == AMF_ERROR_UNKNOWN_TYPE) {
            /* end tag or unknown element: end of data, exit loop */
            amf_data_free(name);
            amf_data_free(element);
            break;
        }
        else if (error_code != AMF_ERROR_OK) {
            amf_data_free(name);
            amf_data_free(data);
            amf_data_free(element);
            return amf_data_error(error_code);
        }

        if (amf_object_add(data, (char *)amf_string_get_bytes(name), element) == NULL) {
            amf_data_free(name);
            amf_data_free(element);
            amf_data_free(data);
            return NULL;
        }
        else {
            amf_data_free(name);
        }
    }

    return data;
}

/* read an associative array */
static amf_data * amf_associative_array_read(amf_read_proc read_proc, void * user_data) {
    amf_data * name;
    amf_data * element;
    uint32_be size;
    byte error_code;
    amf_data * data;
    
    data = amf_associative_array_new();
    if (data == NULL) {
        return NULL;
    }

    /* we ignore the 32 bits array size marker */
    if (read_proc(&size, sizeof(uint32_be), user_data) < sizeof(uint32_be)) {
        amf_data_free(data);
        return amf_data_error(AMF_ERROR_EOF);
    }

    while(1) {
        name = amf_string_read(read_proc, user_data);
        error_code = amf_data_get_error_code(name);
        if (error_code != AMF_ERROR_OK) {
            /* invalid name: error */
            amf_data_free(name);
            amf_data_free(data);
            return amf_data_error(error_code);
        }

        element = amf_data_read(read_proc, user_data);
        error_code = amf_data_get_error_code(element);

        if (amf_string_get_size(name) == 0 || error_code == AMF_ERROR_END_TAG || error_code == AMF_ERROR_UNKNOWN_TYPE) {
            /* end tag or unknown element: end of data, exit loop */
            amf_data_free(name);
            amf_data_free(element);
            break;
        }
        else if (error_code != AMF_ERROR_OK) {
            amf_data_free(name);
            amf_data_free(data);
            amf_data_free(element);
            return amf_data_error(error_code);
        }
        
        if (amf_associative_array_add(data, (char *)amf_string_get_bytes(name), element) == NULL) {
            amf_data_free(name);
            amf_data_free(element);
            amf_data_free(data);
            return NULL;
        }
        else {
            amf_data_free(name);
        }
    }

    return data;
}

/* read an array */
static amf_data * amf_array_read(amf_read_proc read_proc, void * user_data) {
    size_t i;
    amf_data * element;
    byte error_code;
    amf_data * data;
    uint32 array_size;

    data = amf_array_new();
    if (data == NULL) {
        return NULL;
    }
    
    if (read_proc(&array_size, sizeof(uint32), user_data) < sizeof(uint32)) {
        amf_data_free(data);
        return amf_data_error(AMF_ERROR_EOF);
    }

    array_size = swap_uint32(array_size);
            
    for (i = 0; i < array_size; ++i) {
        element = amf_data_read(read_proc, user_data);
        error_code = amf_data_get_error_code(element);
        if (error_code != AMF_ERROR_OK) {
            amf_data_free(element);
            amf_data_free(data);
            return amf_data_error(error_code);
        }
            
        if (amf_array_push(data, element) == NULL) {
            amf_data_free(element);
            amf_data_free(data);
            return NULL;
        }
    }

    return data;
}

/* read a date */
static amf_data * amf_date_read(amf_read_proc read_proc, void * user_data) {
    number64_be milliseconds;
    sint16_be timezone;
    if (read_proc(&milliseconds, sizeof(number64_be), user_data) == sizeof(number64_be) &&
        read_proc(&timezone, sizeof(sint16_be), user_data) == sizeof(sint16_be)) {
        return amf_date_new(swap_number64(milliseconds), swap_sint16(timezone));
    }
    else {
        return amf_data_error(AMF_ERROR_EOF);
    }
}

/* load AMF data from stream */
amf_data * amf_data_read(amf_read_proc read_proc, void * user_data) {
    byte type;
    if (read_proc(&type, sizeof(byte), user_data) < sizeof(byte)) {
        return amf_data_error(AMF_ERROR_EOF);
    }
        
    switch (type) {
        case AMF_TYPE_NUMBER:
            return amf_number_read(read_proc, user_data);
        case AMF_TYPE_BOOLEAN:
            return amf_boolean_read(read_proc, user_data);
        case AMF_TYPE_STRING:
            return amf_string_read(read_proc, user_data);
        case AMF_TYPE_OBJECT:
            return amf_object_read(read_proc, user_data);
        case AMF_TYPE_NULL:
            return amf_null_new();
        case AMF_TYPE_UNDEFINED:
            return amf_undefined_new();
        /*case AMF_TYPE_REFERENCE:*/
        case AMF_TYPE_ASSOCIATIVE_ARRAY:
            return amf_associative_array_read(read_proc, user_data);
        case AMF_TYPE_ARRAY:
            return amf_array_read(read_proc, user_data);
        case AMF_TYPE_DATE:
            return amf_date_read(read_proc, user_data);
        /*case AMF_TYPE_SIMPLEOBJECT:*/
        case AMF_TYPE_XML:
        case AMF_TYPE_CLASS:
            return amf_data_error(AMF_ERROR_UNSUPPORTED_TYPE);
        case AMF_TYPE_END:
            return amf_data_error(AMF_ERROR_END_TAG); /* end of composite object */
        default:
            return amf_data_error(AMF_ERROR_UNKNOWN_TYPE);
    }
}

/* determines the size of the given AMF data */
size_t amf_data_size(const amf_data * data) {
    size_t s = 0;
    amf_node * node;
    if (data != NULL) {
        s += sizeof(byte);
        switch (data->type) {
            case AMF_TYPE_NUMBER:
                s += sizeof(number64_be);
                break;
            case AMF_TYPE_BOOLEAN:
                s += sizeof(uint8);
                break;
            case AMF_TYPE_STRING:
                s += sizeof(uint16) + (size_t)amf_string_get_size(data);
                break;
            case AMF_TYPE_OBJECT:
                node = amf_object_first(data);
                while (node != NULL) {
                    s += sizeof(uint16) + (size_t)amf_string_get_size(amf_object_get_name(node));
                    s += (size_t)amf_data_size(amf_object_get_data(node));
                    node = amf_object_next(node);
                }
                s += sizeof(uint16) + sizeof(uint8);
                break;
            case AMF_TYPE_NULL:
            case AMF_TYPE_UNDEFINED:
                break;
            /*case AMF_TYPE_REFERENCE:*/
            case AMF_TYPE_ASSOCIATIVE_ARRAY:
                s += sizeof(uint32);
                node = amf_associative_array_first(data);
                while (node != NULL) {
                    s += sizeof(uint16) + (size_t)amf_string_get_size(amf_associative_array_get_name(node));
                    s += (size_t)amf_data_size(amf_associative_array_get_data(node));
                    node = amf_associative_array_next(node);
                }
                s += sizeof(uint16) + sizeof(uint8);
                break;
            case AMF_TYPE_ARRAY:
                s += sizeof(uint32);
                node = amf_array_first(data);
                while (node != NULL) {
                    s += (size_t)amf_data_size(amf_array_get(node));
                    node = amf_array_next(node);
                }
                break;
            case AMF_TYPE_DATE:
                s += sizeof(number64) + sizeof(sint16);
                break;
            /*case AMF_TYPE_SIMPLEOBJECT:*/
            case AMF_TYPE_XML:
            case AMF_TYPE_CLASS:
            case AMF_TYPE_END:
                break; /* end of composite object */
            default:
                break;
        }
    }
    return s;
}

/* write a number */
static size_t amf_number_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    number64 n = swap_number64(data->number_data);
    return write_proc(&n, sizeof(number64_be), user_data);
}

/* write a boolean */
static size_t amf_boolean_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    return write_proc(&(data->boolean_data), sizeof(uint8), user_data);
}

/* write a string */
static size_t amf_string_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    uint16 s;
    size_t w = 0;

    s = swap_uint16(data->string_data.size);
    w = write_proc(&s, sizeof(uint16_be), user_data);
    if (data->string_data.size > 0) {
        w += write_proc(data->string_data.mbstr, (size_t)(data->string_data.size), user_data);
    }

    return w;
}

/* write an object */
static size_t amf_object_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    amf_node * node;
    size_t w = 0;
    uint16_be filler = swap_uint16(0);
    uint8 terminator = AMF_TYPE_END;

    node = amf_object_first(data);
    while (node != NULL) {
        w += amf_string_write(amf_object_get_name(node), write_proc, user_data);
        w += amf_data_write(amf_object_get_data(node), write_proc, user_data);
        node = amf_object_next(node);
    }

    /* empty string is the last element */
    w += write_proc(&filler, sizeof(uint16_be), user_data);
    /* an object ends with 0x09 */
    w += write_proc(&terminator, sizeof(uint8), user_data);

    return w;
}

/* write an associative array */
static size_t amf_associative_array_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    amf_node * node;
    size_t w = 0;
    uint32_be s;
    uint16_be filler = swap_uint16(0);
    uint8 terminator = AMF_TYPE_END;

    s = swap_uint32(data->list_data.size) / 2;
    w += write_proc(&s, sizeof(uint32_be), user_data);
    node = amf_associative_array_first(data);
    while (node != NULL) {
        w += amf_string_write(amf_associative_array_get_name(node), write_proc, user_data);
        w += amf_data_write(amf_associative_array_get_data(node), write_proc, user_data);
        node = amf_associative_array_next(node);
    }

    /* empty string is the last element */
    w += write_proc(&filler, sizeof(uint16_be), user_data);
    /* an object ends with 0x09 */
    w += write_proc(&terminator, sizeof(uint8), user_data);

    return w;
}

/* write an array */
static size_t amf_array_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    amf_node * node;
    size_t w = 0;
    uint32_be s;

    s = swap_uint32(data->list_data.size);
    w += write_proc(&s, sizeof(uint32_be), user_data);
    node = amf_array_first(data);
    while (node != NULL) {
        w += amf_data_write(amf_array_get(node), write_proc, user_data);
        node = amf_array_next(node);
    }

    return w;
}

/* write a date */
static size_t amf_date_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    size_t w = 0;
    number64_be milli;
    sint16_be tz;

    milli = swap_number64(data->date_data.milliseconds);
    w += write_proc(&milli, sizeof(number64_be), user_data);
    tz = swap_sint16(data->date_data.timezone);
    w += write_proc(&tz, sizeof(sint16_be), user_data);

    return w;
}

/* write amf data to stream */
size_t amf_data_write(const amf_data * data, amf_write_proc write_proc, void * user_data) {
    size_t s = 0;
    if (data != NULL) {
        s += write_proc(&(data->type), sizeof(byte), user_data);
        switch (data->type) {
            case AMF_TYPE_NUMBER:
                s += amf_number_write(data, write_proc, user_data);
                break;
            case AMF_TYPE_BOOLEAN:
                s += amf_boolean_write(data, write_proc, user_data);
                break;
            case AMF_TYPE_STRING:
                s += amf_string_write(data, write_proc, user_data);
                break;
            case AMF_TYPE_OBJECT:
                s += amf_object_write(data, write_proc, user_data);
                break;
            case AMF_TYPE_NULL:
            case AMF_TYPE_UNDEFINED:
                break;
            /*case AMF_TYPE_REFERENCE:*/
            case AMF_TYPE_ASSOCIATIVE_ARRAY:
                s += amf_associative_array_write(data, write_proc, user_data);
                break;
            case AMF_TYPE_ARRAY:
                s += amf_array_write(data, write_proc, user_data);
                break;
            case AMF_TYPE_DATE:
                s += amf_date_write(data, write_proc, user_data);
                break;
            /*case AMF_TYPE_SIMPLEOBJECT:*/
            case AMF_TYPE_XML:
            case AMF_TYPE_CLASS:
            case AMF_TYPE_END:
                break; /* end of composite object */
            default:
                break;
        }
    }
    return s;
}

/* data type */
byte amf_data_get_type(const amf_data * data) {
    return (data != NULL) ? data->type : AMF_TYPE_NULL;
}

/* error code */
byte amf_data_get_error_code(const amf_data * data) {
    return (data != NULL) ? data->error_code : AMF_ERROR_NULL_POINTER;
}

/* clone AMF data */
amf_data * amf_data_clone(const amf_data * data) {
    /* we copy data recursively */
    if (data != NULL) {
        switch (data->type) {
            case AMF_TYPE_NUMBER: return amf_number_new(amf_number_get_value(data));
            case AMF_TYPE_BOOLEAN: return amf_boolean_new(amf_boolean_get_value(data));
            case AMF_TYPE_STRING:
                if (data->string_data.mbstr != NULL) {
                    return amf_string_new((byte *)strdup((char *)amf_string_get_bytes(data)), amf_string_get_size(data));
                }
                else {
                    return amf_str(NULL);
                }
            case AMF_TYPE_NULL: return NULL;
            case AMF_TYPE_UNDEFINED: return NULL;
            /*case AMF_TYPE_REFERENCE:*/
            case AMF_TYPE_OBJECT:
            case AMF_TYPE_ASSOCIATIVE_ARRAY:
            case AMF_TYPE_ARRAY:
                {
                    amf_data * d = amf_data_new(data->type);
                    if (d != NULL) {
                        amf_list_init(&d->list_data);
                        amf_list_clone(&data->list_data, &d->list_data);
                    }
                    return d;
                }
            case AMF_TYPE_DATE: return amf_date_new(amf_date_get_milliseconds(data), amf_date_get_timezone(data));
            /*case AMF_TYPE_SIMPLEOBJECT:*/
            case AMF_TYPE_XML: return NULL;
            case AMF_TYPE_CLASS: return NULL;
        }
    }
    return NULL;
}

/* free AMF data */
void amf_data_free(amf_data * data) {
    if (data != NULL) {
        switch (data->type) {
            case AMF_TYPE_NUMBER: break;
            case AMF_TYPE_BOOLEAN: break;
            case AMF_TYPE_STRING:
                if (data->string_data.mbstr != NULL) {
                    free(data->string_data.mbstr);
                } break;
            case AMF_TYPE_NULL: break;
            case AMF_TYPE_UNDEFINED: break;
            /*case AMF_TYPE_REFERENCE:*/
            case AMF_TYPE_OBJECT:
            case AMF_TYPE_ASSOCIATIVE_ARRAY:
            case AMF_TYPE_ARRAY: amf_list_clear(&data->list_data); break;
            case AMF_TYPE_DATE: break;
            /*case AMF_TYPE_SIMPLEOBJECT:*/
            case AMF_TYPE_XML: break;
            case AMF_TYPE_CLASS: break;
            default: break;
        }
        free(data);
    }
}

/* dump AMF data into a stream as text */
void amf_data_dump(FILE * stream, const amf_data * data, int indent_level) {
    if (data != NULL) {
        amf_node * node;
        time_t time;
        struct tm * t = NULL;
        char datestr[128];
        switch (data->type) {
            case AMF_TYPE_NUMBER:
                fprintf(stream, "%.12g", data->number_data);
                break;
            case AMF_TYPE_BOOLEAN:
                fprintf(stream, "%s", (data->boolean_data) ? "true" : "false");
                break;
            case AMF_TYPE_STRING:
                fprintf(stream, "\'%.*s\'", data->string_data.size, data->string_data.mbstr);
                break;
            case AMF_TYPE_OBJECT:
                node = amf_object_first(data);
                fprintf(stream, "{\n");
                while (node != NULL) {
                    fprintf(stream, "%*s", (indent_level+1)*4, "");
                    amf_data_dump(stream, amf_object_get_name(node), indent_level+1);
                    fprintf(stream, ": ");
                    amf_data_dump(stream, amf_object_get_data(node), indent_level+1);
                    node = amf_object_next(node);
                    fprintf(stream, "\n");
                }
                fprintf(stream, "%*s", indent_level*4 + 1, "}");
                break;
            case AMF_TYPE_NULL:
                fprintf(stream, "null");
                break;
            case AMF_TYPE_UNDEFINED:
                fprintf(stream, "undefined");
                break;
            /*case AMF_TYPE_REFERENCE:*/
            case AMF_TYPE_ASSOCIATIVE_ARRAY:
                node = amf_associative_array_first(data);
                fprintf(stream, "{\n");
                while (node != NULL) {
                    fprintf(stream, "%*s", (indent_level+1)*4, "");
                    amf_data_dump(stream, amf_associative_array_get_name(node), indent_level+1);
                    fprintf(stream, " => ");
                    amf_data_dump(stream, amf_associative_array_get_data(node), indent_level+1);
                    node = amf_associative_array_next(node);
                    fprintf(stream, "\n");
                }
                fprintf(stream, "%*s", indent_level*4 + 1, "}");
                break;
            case AMF_TYPE_ARRAY:
                node = amf_array_first(data);
                fprintf(stream, "[\n");
                while (node != NULL) {
                    fprintf(stream, "%*s", (indent_level+1)*4, "");
                    amf_data_dump(stream, node->data, indent_level+1);
                    node = amf_array_next(node);
                    fprintf(stream, "\n");
                }
                fprintf(stream, "%*s", indent_level*4 + 1, "]");
                break;
            case AMF_TYPE_DATE:
                time = amf_date_to_time_t(data);
                tzset();
                localtime_r(&time,t);
                strftime(datestr, sizeof(datestr), "%a, %d %b %Y %H:%M:%S %z", t);
                fprintf(stream, "%s", datestr);
                break;
            /*case AMF_TYPE_SIMPLEOBJECT:*/
            case AMF_TYPE_XML: break;
            case AMF_TYPE_CLASS: break;
            default: break;
        }
    }
}

/* return a null AMF object with the specified error code attached to it */
amf_data * amf_data_error(byte error_code) {
    amf_data * data = amf_null_new();
    if (data != NULL) {
        data->error_code = error_code;
    }
    return data;
}

/* number functions */
amf_data * amf_number_new(number64 value) {
    amf_data * data = amf_data_new(AMF_TYPE_NUMBER);
    if (data != NULL) {
        data->number_data = value;
    }
    return data;
}

amf_data * amf_number_double(double value) {
	amf_data * data = amf_data_new(AMF_TYPE_NUMBER);
	if (data != NULL) {
		data->number_data = value;
	}
	return data;
}

number64 amf_number_get_value(const amf_data * data) {
    return (data != NULL) ? data->number_data : 0;
}

void amf_number_set_value(amf_data * data, number64 value) {
    if (data != NULL) {
        data->number_data = value;
    }
}

/* boolean functions */
amf_data * amf_boolean_new(uint8 value) {
    amf_data * data = amf_data_new(AMF_TYPE_BOOLEAN);
    if (data != NULL) {
        data->boolean_data = value;
    }
    return data;
}

uint8 amf_boolean_get_value(const amf_data * data) {
    return (data != NULL) ? data->boolean_data : 0;
}

void amf_boolean_set_value(amf_data * data, uint8 value) {
    if (data != NULL) {
        data->boolean_data = value;
    }
}

/* string functions */
amf_data * amf_string_new(byte * str, uint16 size) {
    amf_data * data = amf_data_new(AMF_TYPE_STRING);
    if (data != NULL) {
        if (str == NULL) {
            data->string_data.size = 0;
        }
        else {
            data->string_data.size = size;
        }
        data->string_data.mbstr = (byte*)calloc(size+1, sizeof(byte));
        if (data->string_data.mbstr != NULL) {
            if (data->string_data.size > 0) {
                memcpy(data->string_data.mbstr, str, data->string_data.size);
            }
        }
        else {
            amf_data_free(data);
            return NULL;
        }
    }
    return data;
}

amf_data * amf_str(const char * str) {
    return amf_string_new((byte *)str, (uint16)(str != NULL ? strlen(str) : 0));
}

uint16 amf_string_get_size(const amf_data * data) {
    return (data != NULL) ? data->string_data.size : 0;
}

byte * amf_string_get_bytes(const amf_data * data) {
    return (data != NULL) ? data->string_data.mbstr : NULL;
}

/* object functions */
amf_data * amf_object_new(void) {
    amf_data * data = amf_data_new(AMF_TYPE_OBJECT);
    if (data != NULL) {
        amf_list_init(&data->list_data);
    }
    return data;
}

uint32 amf_object_size(const amf_data * data) {
    return (data != NULL) ? data->list_data.size / 2 : 0;
}

amf_data * amf_object_add(amf_data * data, const char * name, amf_data * element) {
    if (data != NULL) {
        if (amf_list_push(&data->list_data, amf_str(name)) != NULL) {
            if (amf_list_push(&data->list_data, element) != NULL) {
                return element;
            }
            else {
                amf_data_free(amf_list_pop(&data->list_data));
            }
        }
    }
    return NULL;
}

amf_data * amf_object_get(const amf_data * data, const char * name) {
    if (data != NULL) {
        amf_node * node = amf_list_first(&(data->list_data));
        while (node != NULL) {
            if (strncmp((char*)(node->data->string_data.mbstr), name, (size_t)(node->data->string_data.size)) == 0) {
                node = node->next;
                return (node != NULL) ? node->data : NULL;
            }
            /* we have to skip the element data to reach the next name */
            node = node->next->next;
        }
    }
    return NULL;
}

amf_data * amf_object_set(amf_data * data, const char * name, amf_data * element) {
    if (data != NULL) {
        amf_node * node = amf_list_first(&(data->list_data));
        while (node != NULL) {
            if (strncmp((char*)(node->data->string_data.mbstr), name, (size_t)(node->data->string_data.size)) == 0) {
                node = node->next;
                if (node != NULL && node->data != NULL) {
                    amf_data_free(node->data);
                    node->data = element;
                    return element;
                }
            }
            /* we have to skip the element data to reach the next name */
            node = node->next->next;
        }
    }
    return NULL;
}

amf_data * amf_object_delete(amf_data * data, const char * name) {
    if (data != NULL) {
        amf_node * node = amf_list_first(&data->list_data);
        while (node != NULL) {
            node = node->next;
            if (strncmp((char*)(node->data->string_data.mbstr), name, (size_t)(node->data->string_data.size)) == 0) {
                amf_node * data_node = node->next;
                amf_data_free(amf_list_delete(&data->list_data, node));
                return amf_list_delete(&data->list_data, data_node);
            }
            else {
                node = node->next;
            }
        }
    }
    return NULL;
}

amf_node * amf_object_first(const amf_data * data) {
    return (data != NULL) ? amf_list_first(&data->list_data) : NULL;
}

amf_node * amf_object_last(const amf_data * data) {
    if (data != NULL) {
        amf_node * node = amf_list_last(&data->list_data);
        if (node != NULL) {
            return node->prev;
        }
    }
    return NULL;
}

amf_node * amf_object_next(amf_node * node) {
    if (node != NULL) {
        amf_node * next = node->next;
        if (next != NULL) {
            return next->next;
        }
    }
    return NULL;
}

amf_node * amf_object_prev(amf_node * node) {
    if (node != NULL) {
        amf_node * prev = node->prev;
        if (prev != NULL) {
            return prev->prev;
        }
    }
    return NULL;
}

amf_data * amf_object_get_name(amf_node * node) {
    return (node != NULL) ? node->data : NULL;
}

amf_data * amf_object_get_data(amf_node * node) {
    if (node != NULL) {
        amf_node * next = node->next;
        if (next != NULL) {
            return next->data;
        }
    }
    return NULL;
}

/* associative array functions */
amf_data * amf_associative_array_new(void) {
    amf_data * data = amf_data_new(AMF_TYPE_ASSOCIATIVE_ARRAY);
    if (data != NULL) {
        amf_list_init(&data->list_data);
    }
    return data;
}

/* array functions */
amf_data * amf_array_new(void) {
    amf_data * data = amf_data_new(AMF_TYPE_ARRAY);
    if (data != NULL) {
        amf_list_init(&data->list_data);
    }
    return data;
}

uint32 amf_array_size(const amf_data * data) {
    return (data != NULL) ? data->list_data.size : 0;
}

amf_data * amf_array_push(amf_data * data, amf_data * element) {
    return (data != NULL) ? amf_list_push(&data->list_data, element) : NULL;
}

amf_data * amf_array_pop(amf_data * data) {
    return (data != NULL) ? amf_list_pop(&data->list_data) : NULL;
}

amf_node * amf_array_first(const amf_data * data) {
    return (data != NULL) ? amf_list_first(&data->list_data) : NULL;
}

amf_node * amf_array_last(const amf_data * data) {
    return (data != NULL) ? amf_list_last(&data->list_data) : NULL;
}

amf_node * amf_array_next(amf_node * node) {
    return (node != NULL) ? node->next : NULL;
}

amf_node * amf_array_prev(amf_node * node) {
    return (node != NULL) ? node->prev : NULL;
}

amf_data * amf_array_get(amf_node * node) {
    return (node != NULL) ? node->data : NULL;
}

amf_data * amf_array_get_at(const amf_data * data, uint32 n) {
    return (data != NULL) ? amf_list_get_at(&data->list_data, n) : NULL;
}

amf_data * amf_array_delete(amf_data * data, amf_node * node) {
    return (data != NULL) ? amf_list_delete(&data->list_data, node) : NULL;
}

amf_data * amf_array_insert_before(amf_data * data, amf_node * node, amf_data * element) {
    return (data != NULL) ? amf_list_insert_before(&data->list_data, node, element) : NULL;
}

amf_data * amf_array_insert_after(amf_data * data, amf_node * node, amf_data * element) {
    return (data != NULL) ? amf_list_insert_after(&data->list_data, node, element) : NULL;
}

/* date functions */
amf_data * amf_date_new(number64 milliseconds, sint16 timezone) {
    amf_data * data = amf_data_new(AMF_TYPE_DATE);
    if (data != NULL) {
        data->date_data.milliseconds = milliseconds;
        data->date_data.timezone = timezone;
    }
    return data;
}

number64 amf_date_get_milliseconds(const amf_data * data) {
    return (data != NULL) ? data->date_data.milliseconds : (number64)0.0;
}

sint16 amf_date_get_timezone(const amf_data * data) {
    return (data != NULL) ? data->date_data.timezone : 0;
}

time_t amf_date_to_time_t(const amf_data * data) {
    return (time_t)((data != NULL) ? data->date_data.milliseconds / 1000 : 0);
}
