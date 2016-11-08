#ifndef __ERROR_H__
#define __ERROR_H__

#include <stdlib.h>

typedef struct RTMPError {
    int code;
    char *message;
} RTMPError;

void RTMPError_Alloc(RTMPError *error, size_t msg_size);
void RTMPError_Free(RTMPError *error);

// error defines
enum {
    RTMPErrorUnknow = -1, //	"Unknow error"
    RTMPErrorUnknowOption = -999, //	"Unknown option %s"
    RTMPErrorAccessDNSFailed = -1000, //	"Failed to access the DNS. (addr: %s)"
    RTMPErrorFailedToConnectSocket =
        -1001, //	"Failed to connect socket. %d (%s)"
    RTMPErrorSocksNegotiationFailed = -1002, //	"Socks negotiation failed"
    RTMPErrorFailedToCreateSocket =
        -1003, //	"Failed to create socket. %d (%s)"
    RTMPErrorHandshakeFailed = -1004, //	"Handshake failed"
    RTMPErrorRTMPConnectFailed = -1005, //	"RTMP connect failed"
    RTMPErrorSendFailed = -1006, //	"Send error %d (%s), (%d bytes)"
    RTMPErrorServerRequestedClose = -1007, //	"RTMP server requested close"
    RTMPErrorNetStreamFailed = -1008, //	"NetStream failed"
    RTMPErrorNetStreamPlayFailed = -1009, //	"NetStream play failed"
    RTMPErrorNetStreamPlayStreamNotFound =
        -1010, //	"NetStream play stream not found"
    RTMPErrorNetConnectionConnectInvalidApp =
        -1011, //	"NetConnection connect invalip app"
    RTMPErrorSanityFailed =
        -1012, //	"Sanity failed. Trying to send header of type: 0x%02X"
    RTMPErrorSocketClosedByPeer = -1013, // "RTMP socket closed by peer"
    RTMPErrorRTMPConnectStreamFailed = -1014, // "RTMP connect stream failed"
    RTMPErrorSocketTimeout = -1015, // "RTMP socket timeout"

    // SSL errors
    RTMPErrorTLSConnectFailed = -1200, //	"TLS_Connect failed"
    RTMPErrorNoSSLOrTLSSupport = -1201, //	"No SSL/TLS support"
};

#endif
