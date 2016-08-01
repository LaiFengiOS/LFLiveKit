#ifndef __RTMP_H__
#define __RTMP_H__
/*
 *      Copyright (C) 2005-2008 Team XBMC
 *      http://www.xbmc.org
 *      Copyright (C) 2008-2009 Andrej Stepanchuk
 *      Copyright (C) 2009-2010 Howard Chu
 *
 *  This file is part of librtmp.
 *
 *  librtmp is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as
 *  published by the Free Software Foundation; either version 2.1,
 *  or (at your option) any later version.
 *
 *  librtmp is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with librtmp see the file COPYING.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA  02110-1301, USA.
 *  http://www.gnu.org/copyleft/lgpl.html
 */

#define NO_CRYPTO

#if !defined(NO_CRYPTO) && !defined(CRYPTO)
#define CRYPTO
#endif

#include <errno.h>
#include <stddef.h>
#include <stdint.h>

#include "amf.h"
#include "error.h"

#ifdef __cplusplus
extern "C" {
#endif

#define RTMP_LIB_VERSION 0x020300 /* 2.3 */

#define RTMP_FEATURE_HTTP 0x01
#define RTMP_FEATURE_ENC 0x02
#define RTMP_FEATURE_SSL 0x04
#define RTMP_FEATURE_MFP 0x08 /* not yet supported */
#define RTMP_FEATURE_WRITE 0x10 /* publish, not play */
#define RTMP_FEATURE_HTTP2 0x20 /* server-side rtmpt */

#define RTMP_PROTOCOL_UNDEFINED -1
#define RTMP_PROTOCOL_RTMP 0
#define RTMP_PROTOCOL_RTMPE RTMP_FEATURE_ENC
#define RTMP_PROTOCOL_RTMPT RTMP_FEATURE_HTTP
#define RTMP_PROTOCOL_RTMPS RTMP_FEATURE_SSL
#define RTMP_PROTOCOL_RTMPTE (RTMP_FEATURE_HTTP | RTMP_FEATURE_ENC)
#define RTMP_PROTOCOL_RTMPTS (RTMP_FEATURE_HTTP | RTMP_FEATURE_SSL)
#define RTMP_PROTOCOL_RTMFP RTMP_FEATURE_MFP

#define RTMP_DEFAULT_CHUNKSIZE 128

/* needs to fit largest number of bytes recv() may return */
#define RTMP_BUFFER_CACHE_SIZE (16 * 1024)

#define RTMP_CHANNELS 65600

extern const char PILI_RTMPProtocolStringsLower[][7];
extern const AVal PILI_RTMP_DefaultFlashVer;
extern int PILI_RTMP_ctrlC;

uint32_t PILI_RTMP_GetTime(void);

#define RTMP_PACKET_TYPE_AUDIO 0x08
#define RTMP_PACKET_TYPE_VIDEO 0x09
#define RTMP_PACKET_TYPE_INFO 0x12

#define RTMP_MAX_HEADER_SIZE 18

#define RTMP_PACKET_SIZE_LARGE 0
#define RTMP_PACKET_SIZE_MEDIUM 1
#define RTMP_PACKET_SIZE_SMALL 2
#define RTMP_PACKET_SIZE_MINIMUM 3

typedef struct PILI_RTMPChunk {
    int c_headerSize;
    int c_chunkSize;
    char *c_chunk;
    char c_header[RTMP_MAX_HEADER_SIZE];
} PILI_RTMPChunk;

typedef struct PILI_RTMPPacket {
    uint8_t m_headerType;
    uint8_t m_packetType;
    uint8_t m_hasAbsTimestamp; /* timestamp absolute or relative? */
    int m_nChannel;
    uint32_t m_nTimeStamp; /* timestamp */
    int32_t m_nInfoField2; /* last 4 bytes in a long header */
    uint32_t m_nBodySize;
    uint32_t m_nBytesRead;
    PILI_RTMPChunk *m_chunk;
    char *m_body;
} PILI_RTMPPacket;

typedef struct PILI_RTMPSockBuf {
    int sb_socket;
    int sb_size; /* number of unprocessed bytes in buffer */
    char *sb_start; /* pointer into sb_pBuffer of next byte to process */
    char sb_buf[RTMP_BUFFER_CACHE_SIZE]; /* data read from socket */
    int sb_timedout;
    void *sb_ssl;
} PILI_RTMPSockBuf;

void PILI_RTMPPacket_Reset(PILI_RTMPPacket *p);
void PILI_RTMPPacket_Dump(PILI_RTMPPacket *p);
int PILI_RTMPPacket_Alloc(PILI_RTMPPacket *p, int nSize);
void PILI_RTMPPacket_Free(PILI_RTMPPacket *p);

#define RTMPPacket_IsReady(a) ((a)->m_nBytesRead == (a)->m_nBodySize)

typedef struct PILI_RTMP_LNK {
    AVal hostname;
    AVal domain;
    AVal sockshost;

    AVal playpath0; /* parsed from URL */
    AVal playpath; /* passed in explicitly */
    AVal tcUrl;
    AVal swfUrl;
    AVal pageUrl;
    AVal app;
    AVal auth;
    AVal flashVer;
    AVal subscribepath;
    AVal token;
    AMFObject extras;
    int edepth;

    int seekTime;
    int stopTime;

#define RTMP_LF_AUTH 0x0001 /* using auth param */
#define RTMP_LF_LIVE 0x0002 /* stream is live */
#define RTMP_LF_SWFV 0x0004 /* do SWF verification */
#define RTMP_LF_PLST 0x0008 /* send playlist before play */
#define RTMP_LF_BUFX 0x0010 /* toggle stream on BufferEmpty msg */
#define RTMP_LF_FTCU 0x0020 /* free tcUrl on close */
    int lFlags;

    int swfAge;

    int protocol;
    int timeout; /* connection timeout in seconds */
    int send_timeout; /* send data timeout */

    unsigned short socksport;
    unsigned short port;

#ifdef CRYPTO
#define RTMP_SWF_HASHLEN 32
    void *dh; /* for encryption */
    void *rc4keyIn;
    void *rc4keyOut;

    uint32_t SWFSize;
    uint8_t SWFHash[RTMP_SWF_HASHLEN];
    char SWFVerificationResponse[RTMP_SWF_HASHLEN + 10];
#endif
} PILI_RTMP_LNK;

/* state for read() wrapper */
typedef struct PILI_RTMP_READ {
    char *buf;
    char *bufpos;
    unsigned int buflen;
    uint32_t timestamp;
    uint8_t dataType;
    uint8_t flags;
#define RTMP_READ_HEADER 0x01
#define RTMP_READ_RESUME 0x02
#define RTMP_READ_NO_IGNORE 0x04
#define RTMP_READ_GOTKF 0x08
#define RTMP_READ_GOTFLVK 0x10
#define RTMP_READ_SEEKING 0x20
    int8_t status;
#define RTMP_READ_COMPLETE -3
#define RTMP_READ_ERROR -2
#define RTMP_READ_EOF -1
#define RTMP_READ_IGNORE 0

    /* if bResume == TRUE */
    uint8_t initialFrameType;
    uint32_t nResumeTS;
    char *metaHeader;
    char *initialFrame;
    uint32_t nMetaHeaderSize;
    uint32_t nInitialFrameSize;
    uint32_t nIgnoredFrameCounter;
    uint32_t nIgnoredFlvFrameCounter;
} PILI_RTMP_READ;

typedef struct PILI_RTMP_METHOD {
    AVal name;
    int num;
} PILI_RTMP_METHOD;

typedef void (*PILI_RTMPErrorCallback)(RTMPError *error, void *userData);

typedef struct PILI_CONNECTION_TIME {
    uint32_t connect_time;
    uint32_t handshake_time;
} PILI_CONNECTION_TIME;

typedef void (*PILI_RTMP_ConnectionTimeCallback)(
    PILI_CONNECTION_TIME *conn_time, void *userData);

typedef struct PILI_RTMP {
    int m_inChunkSize;
    int m_outChunkSize;
    int m_nBWCheckCounter;
    int m_nBytesIn;
    int m_nBytesInSent;
    int m_nBufferMS;
    int m_stream_id; /* returned in _result from createStream */
    int m_mediaChannel;
    uint32_t m_mediaStamp;
    uint32_t m_pauseStamp;
    int m_pausing;
    int m_nServerBW;
    int m_nClientBW;
    uint8_t m_nClientBW2;
    uint8_t m_bPlaying;
    uint8_t m_bSendEncoding;
    uint8_t m_bSendCounter;

    int m_numInvokes;
    int m_numCalls;
    PILI_RTMP_METHOD *m_methodCalls; /* remote method calls queue */

    PILI_RTMPPacket *m_vecChannelsIn[RTMP_CHANNELS];
    PILI_RTMPPacket *m_vecChannelsOut[RTMP_CHANNELS];
    int m_channelTimestamp[RTMP_CHANNELS]; /* abs timestamp of last packet */

    double m_fAudioCodecs; /* audioCodecs for the connect packet */
    double m_fVideoCodecs; /* videoCodecs for the connect packet */
    double m_fEncoding; /* AMF0 or AMF3 */

    double m_fDuration; /* duration of stream in seconds */

    int m_msgCounter; /* RTMPT stuff */
    int m_polling;
    int m_resplen;
    int m_unackd;
    AVal m_clientID;

    PILI_RTMP_READ m_read;
    PILI_RTMPPacket m_write;
    PILI_RTMPSockBuf m_sb;
    PILI_RTMP_LNK Link;

    PILI_RTMPErrorCallback m_errorCallback;
    PILI_RTMP_ConnectionTimeCallback m_connCallback;
    RTMPError *m_error;
    void *m_userData;
    int m_is_closing;
    int m_tcp_nodelay;
    uint32_t ip;
} PILI_RTMP;

int PILI_RTMP_ParseURL(const char *url, int *protocol, AVal *host,
                       unsigned int *port, AVal *playpath, AVal *app);

int PILI_RTMP_ParseURL2(const char *url, int *protocol, AVal *host,
                        unsigned int *port, AVal *playpath, AVal *app, AVal *domain);

void PILI_RTMP_ParsePlaypath(AVal *in, AVal *out);
void PILI_RTMP_SetBufferMS(PILI_RTMP *r, int size);
void PILI_RTMP_UpdateBufferMS(PILI_RTMP *r, RTMPError *error);

int PILI_RTMP_SetOpt(PILI_RTMP *r, const AVal *opt, AVal *arg,
                     RTMPError *error);
int PILI_RTMP_SetupURL(PILI_RTMP *r, const char *url, RTMPError *error);
void PILI_RTMP_SetupStream(PILI_RTMP *r, int protocol, AVal *hostname,
                           unsigned int port, AVal *sockshost, AVal *playpath,
                           AVal *tcUrl, AVal *swfUrl, AVal *pageUrl, AVal *app,
                           AVal *auth, AVal *swfSHA256Hash, uint32_t swfSize,
                           AVal *flashVer, AVal *subscribepath, int dStart,
                           int dStop, int bLiveStream, long int timeout);

int PILI_RTMP_Connect(PILI_RTMP *r, PILI_RTMPPacket *cp, RTMPError *error);
struct sockaddr;
int PILI_RTMP_Connect0(PILI_RTMP *r, struct addrinfo *ai, unsigned short port,
                       RTMPError *error);
int PILI_RTMP_Connect1(PILI_RTMP *r, PILI_RTMPPacket *cp, RTMPError *error);
int PILI_RTMP_Serve(PILI_RTMP *r, RTMPError *error);

int PILI_RTMP_ReadPacket(PILI_RTMP *r, PILI_RTMPPacket *packet);
int PILI_RTMP_SendPacket(PILI_RTMP *r, PILI_RTMPPacket *packet, int queue,
                         RTMPError *error);
int PILI_RTMP_SendChunk(PILI_RTMP *r, PILI_RTMPChunk *chunk, RTMPError *error);
int PILI_RTMP_IsConnected(PILI_RTMP *r);
int PILI_RTMP_Socket(PILI_RTMP *r);
int PILI_RTMP_IsTimedout(PILI_RTMP *r);
double PILI_RTMP_GetDuration(PILI_RTMP *r);
int PILI_RTMP_ToggleStream(PILI_RTMP *r, RTMPError *error);

int PILI_RTMP_ConnectStream(PILI_RTMP *r, int seekTime, RTMPError *error);
int PILI_RTMP_ReconnectStream(PILI_RTMP *r, int seekTime, RTMPError *error);
void PILI_RTMP_DeleteStream(PILI_RTMP *r, RTMPError *error);
int PILI_RTMP_GetNextMediaPacket(PILI_RTMP *r, PILI_RTMPPacket *packet);
int PILI_RTMP_ClientPacket(PILI_RTMP *r, PILI_RTMPPacket *packet);

void PILI_RTMP_Init(PILI_RTMP *r);
void PILI_RTMP_Close(PILI_RTMP *r, RTMPError *error);
PILI_RTMP *PILI_RTMP_Alloc(void);
void PILI_RTMP_Free(PILI_RTMP *r);
void PILI_RTMP_EnableWrite(PILI_RTMP *r);

int PILI_RTMP_LibVersion(void);
void PILI_RTMP_UserInterrupt(void); /* user typed Ctrl-C */

int PILI_RTMP_SendCtrl(PILI_RTMP *r, short nType, unsigned int nObject,
                       unsigned int nTime, RTMPError *error);

/* caller probably doesn't know current timestamp, should
   * just use RTMP_Pause instead
   */
int PILI_RTMP_SendPause(PILI_RTMP *r, int DoPause, int dTime, RTMPError *error);
int PILI_RTMP_Pause(PILI_RTMP *r, int DoPause, RTMPError *error);

int PILI_RTMP_FindFirstMatchingProperty(AMFObject *obj, const AVal *name,
                                        AMFObjectProperty *p);

int PILI_RTMPSockBuf_Fill(PILI_RTMPSockBuf *sb);
int PILI_RTMPSockBuf_Send(PILI_RTMPSockBuf *sb, const char *buf, int len);
int PILI_RTMPSockBuf_Close(PILI_RTMPSockBuf *sb);

int PILI_RTMP_SendCreateStream(PILI_RTMP *r, RTMPError *error);
int PILI_RTMP_SendSeek(PILI_RTMP *r, int dTime, RTMPError *error);
int PILI_RTMP_SendServerBW(PILI_RTMP *r, RTMPError *error);
int PILI_RTMP_SendClientBW(PILI_RTMP *r, RTMPError *error);
void PILI_RTMP_DropRequest(PILI_RTMP *r, int i, int freeit);
int PILI_RTMP_Read(PILI_RTMP *r, char *buf, int size);
int PILI_RTMP_Write(PILI_RTMP *r, const char *buf, int size, RTMPError *error);

/* hashswf.c */
int PILI_RTMP_HashSWF(const char *url, unsigned int *size, unsigned char *hash,
                      int age);

#ifdef __cplusplus
};
#endif

#endif
