#include "error.h"
#include <stdlib.h>
#include <string.h>

void RTMPError_Alloc(RTMPError *error, size_t msg_size) {
    RTMPError_Free(error);

    error->code = 0;
    error->message = (char *)malloc(msg_size + 1);
    memset(error->message, 0, msg_size);
}

void RTMPError_Free(RTMPError *error) {
    if (error) {
        if (error->message) {
            free(error->message);
            error->message = NULL;
        }
    }
}
