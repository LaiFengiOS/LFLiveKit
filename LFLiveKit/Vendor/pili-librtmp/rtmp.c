/*
 *      Copyright (C) 2005-2008 Team XBMC
 *      http://www.xbmc.org
 *      Copyright (C) 2008-2009 Andrej Stepanchuk
 *      Copyright (C) 2009-2010 Howard Chu
 *
 *  This file is part of librtmp.
 *
 *  libPILI_RTMP is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as
 *  published by the Free Software Foundation; either version 2.1,
 *  or (at your option) any later version.
 *
 *  libPILI_RTMP is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with libPILI_RTMP see the file COPYING.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA  02110-1301, USA.
 *  http://www.gnu.org/copyleft/lgpl.html
 */

#include <assert.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "log.h"
#include "rtmp_sys.h"

#ifdef CRYPTO
#ifdef USE_POLARSSL
#include <polarssl/havege.h>
#elif defined(USE_GNUTLS)
#include <gnutls/gnutls.h>
#else /* USE_OPENSSL */
#include <openssl/rc4.h>
#include <openssl/ssl.h>
#endif
TLS_CTX RTMP_TLS_ctx;
#endif

#define RTMP_SIG_SIZE 1536
#define RTMP_LARGE_HEADER_SIZE 12

static const int packetSize[] = {12, 8, 4, 1};

int PILI_RTMP_ctrlC;

const char PILI_RTMPProtocolStrings[][7] = {
    "RTMP",
    "RTMPT",
    "RTMPE",
    "RTMPTE",
    "RTMPS",
    "RTMPTS",
    "",
    "",
    "RTMFP"};

const char PILI_RTMPProtocolStringsLower[][7] = {
    "rtmp",
    "rtmpt",
    "rtmpe",
    "rtmpte",
    "rtmps",
    "rtmpts",
    "",
    "",
    "rtmfp"};

static const char *RTMPT_cmds[] = {
    "open",
    "send",
    "idle",
    "close"};

typedef enum {
    RTMPT_OPEN = 0,
    RTMPT_SEND,
    RTMPT_IDLE,
    RTMPT_CLOSE
} RTMPTCmd;

static int DumpMetaData(AMFObject *obj);
static int HandShake(PILI_RTMP *r, int FP9HandShake, RTMPError *error);
static int SocksNegotiate(PILI_RTMP *r, RTMPError *error);

static int SendConnectPacket(PILI_RTMP *r, PILI_RTMPPacket *cp, RTMPError *error);
static int SendCheckBW(PILI_RTMP *r, RTMPError *error);
static int SendCheckBWResult(PILI_RTMP *r, double txn, RTMPError *error);
static int SendDeleteStream(PILI_RTMP *r, double dStreamId, RTMPError *error);
static int SendFCSubscribe(PILI_RTMP *r, AVal *subscribepath, RTMPError *error);
static int SendPlay(PILI_RTMP *r, RTMPError *error);
static int SendBytesReceived(PILI_RTMP *r, RTMPError *error);

#if 0 /* unused */
static int SendBGHasStream(PILI_RTMP *r, double dId, AVal *playpath);
#endif

static int HandleInvoke(PILI_RTMP *r, const char *body, unsigned int nBodySize);
static int HandleMetadata(PILI_RTMP *r, char *body, unsigned int len);
static void HandleChangeChunkSize(PILI_RTMP *r, const PILI_RTMPPacket *packet);
static void HandleAudio(PILI_RTMP *r, const PILI_RTMPPacket *packet);
static void HandleVideo(PILI_RTMP *r, const PILI_RTMPPacket *packet);
static void HandleCtrl(PILI_RTMP *r, const PILI_RTMPPacket *packet);
static void HandleServerBW(PILI_RTMP *r, const PILI_RTMPPacket *packet);
static void HandleClientBW(PILI_RTMP *r, const PILI_RTMPPacket *packet);

static int ReadN(PILI_RTMP *r, char *buffer, int n);
static int WriteN(PILI_RTMP *r, const char *buffer, int n, RTMPError *error);

static void DecodeTEA(AVal *key, AVal *text);

static int HTTP_Post(PILI_RTMP *r, RTMPTCmd cmd, const char *buf, int len);
static int HTTP_read(PILI_RTMP *r, int fill);

#ifndef _WIN32
static int clk_tck;
#endif

#ifdef CRYPTO
#include "handshake.h"
#endif

uint32_t
    PILI_RTMP_GetTime() {
#ifdef _DEBUG
    return 0;
#elif defined(_WIN32)
    return timeGetTime();
#else
    struct tms t;
    if (!clk_tck) clk_tck = sysconf(_SC_CLK_TCK);
    return times(&t) * 1000 / clk_tck;
#endif
}

void PILI_RTMP_UserInterrupt() {
    PILI_RTMP_ctrlC = TRUE;
}

void PILI_RTMPPacket_Reset(PILI_RTMPPacket *p) {
    p->m_headerType = 0;
    p->m_packetType = 0;
    p->m_nChannel = 0;
    p->m_nTimeStamp = 0;
    p->m_nInfoField2 = 0;
    p->m_hasAbsTimestamp = FALSE;
    p->m_nBodySize = 0;
    p->m_nBytesRead = 0;
}

int PILI_RTMPPacket_Alloc(PILI_RTMPPacket *p, int nSize) {
    char *ptr = calloc(1, nSize + RTMP_MAX_HEADER_SIZE);
    if (!ptr)
        return FALSE;
    p->m_body = ptr + RTMP_MAX_HEADER_SIZE;
    p->m_nBytesRead = 0;
    return TRUE;
}

void PILI_RTMPPacket_Free(PILI_RTMPPacket *p) {
    if (p->m_body) {
        free(p->m_body - RTMP_MAX_HEADER_SIZE);
        p->m_body = NULL;
    }
}

void PILI_RTMPPacket_Dump(PILI_RTMPPacket *p) {
    RTMP_Log(RTMP_LOGDEBUG,
             "PILI_RTMP PACKET: packet type: 0x%02x. channel: 0x%02x. info 1: %d info 2: %d. Body size: %lu. body: 0x%02x",
             p->m_packetType, p->m_nChannel, p->m_nTimeStamp, p->m_nInfoField2,
             p->m_nBodySize, p->m_body ? (unsigned char)p->m_body[0] : 0);
}

int PILI_RTMP_LibVersion() {
    return RTMP_LIB_VERSION;
}

void PILI_RTMP_TLS_Init() {
#ifdef CRYPTO
#ifdef USE_POLARSSL
    /* Do this regardless of NO_SSL, we use havege for rtmpe too */
    RTMP_TLS_ctx = calloc(1, sizeof(struct tls_ctx));
    havege_init(&RTMP_TLS_ctx->hs);
#elif defined(USE_GNUTLS) && !defined(NO_SSL)
    /* Technically we need to initialize libgcrypt ourselves if
   * we're not going to call gnutls_global_init(). Ignoring this
   * for now.
   */
    gnutls_global_init();
    RTMP_TLS_ctx = malloc(sizeof(struct tls_ctx));
    gnutls_certificate_allocate_credentials(&RTMP_TLS_ctx->cred);
    gnutls_priority_init(&RTMP_TLS_ctx->prios, "NORMAL", NULL);
    gnutls_certificate_set_x509_trust_file(RTMP_TLS_ctx->cred,
                                           "ca.pem", GNUTLS_X509_FMT_PEM);
#elif !defined(NO_SSL) /* USE_OPENSSL */
    /* libcrypto doesn't need anything special */
    SSL_load_error_strings();
    SSL_library_init();
    OpenSSL_add_all_digests();
    RTMP_TLS_ctx = SSL_CTX_new(SSLv23_method());
    SSL_CTX_set_options(RTMP_TLS_ctx, SSL_OP_ALL);
    SSL_CTX_set_default_verify_paths(RTMP_TLS_ctx);
#endif
#endif
}

PILI_RTMP *
    PILI_RTMP_Alloc() {
    return calloc(1, sizeof(PILI_RTMP));
}

void PILI_RTMP_Free(PILI_RTMP *r) {
    r->m_errorCallback = NULL;
    r->m_userData = NULL;
    RTMPError_Free(r->m_error);
    r->m_error = NULL;

    free(r);
}

void PILI_RTMP_Init(PILI_RTMP *r) {
#ifdef CRYPTO
    if (!RTMP_TLS_ctx)
        RTMP_TLS_Init();
#endif

    memset(r, 0, sizeof(PILI_RTMP));
    r->m_sb.sb_socket = -1;
    r->m_inChunkSize = RTMP_DEFAULT_CHUNKSIZE;
    r->m_outChunkSize = RTMP_DEFAULT_CHUNKSIZE;
    r->m_nBufferMS = 30000;
    r->m_nClientBW = 2500000;
    r->m_nClientBW2 = 2;
    r->m_nServerBW = 2500000;
    r->m_fAudioCodecs = 3191.0;
    r->m_fVideoCodecs = 252.0;
    r->Link.timeout = 10;
    r->Link.send_timeout = 10;
    r->Link.swfAge = 30;

    r->m_errorCallback = NULL;
    r->m_error = NULL;
    r->m_userData = NULL;
    r->m_is_closing = 0;
    r->m_tcp_nodelay = 1;

    r->m_connCallback = NULL;
    r->ip = 0;
}

void PILI_RTMP_EnableWrite(PILI_RTMP *r) {
    r->Link.protocol |= RTMP_FEATURE_WRITE;
}

double
    PILI_RTMP_GetDuration(PILI_RTMP *r) {
    return r->m_fDuration;
}

int PILI_RTMP_IsConnected(PILI_RTMP *r) {
    return r->m_sb.sb_socket != -1;
}

int PILI_RTMP_Socket(PILI_RTMP *r) {
    return r->m_sb.sb_socket;
}

int PILI_RTMP_IsTimedout(PILI_RTMP *r) {
    return r->m_sb.sb_timedout;
}

void PILI_RTMP_SetBufferMS(PILI_RTMP *r, int size) {
    r->m_nBufferMS = size;
}

void PILI_RTMP_UpdateBufferMS(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMP_SendCtrl(r, 3, r->m_stream_id, r->m_nBufferMS, error);
}

#undef OSS
#ifdef _WIN32
#define OSS "WIN"
#elif defined(__sun__)
#define OSS "SOL"
#elif defined(__APPLE__)
#define OSS "MAC"
#elif defined(__linux__)
#define OSS "LNX"
#else
#define OSS "GNU"
#endif
#define DEF_VERSTR OSS " 10,0,32,18"
static const char DEFAULT_FLASH_VER[] = DEF_VERSTR;
const AVal RTMP_DefaultFlashVer =
    {(char *)DEFAULT_FLASH_VER, sizeof(DEFAULT_FLASH_VER) - 1};

void PILI_RTMP_SetupStream(PILI_RTMP *r,
                           int protocol,
                           AVal *host,
                           unsigned int port,
                           AVal *sockshost,
                           AVal *playpath,
                           AVal *tcUrl,
                           AVal *swfUrl,
                           AVal *pageUrl,
                           AVal *app,
                           AVal *auth,
                           AVal *swfSHA256Hash,
                           uint32_t swfSize,
                           AVal *flashVer,
                           AVal *subscribepath,
                           int dStart,
                           int dStop, int bLiveStream, long int timeout) {
    RTMP_Log(RTMP_LOGDEBUG, "Protocol : %s", PILI_RTMPProtocolStrings[protocol & 7]);
    RTMP_Log(RTMP_LOGDEBUG, "Hostname : %.*s", host->av_len, host->av_val);
    RTMP_Log(RTMP_LOGDEBUG, "Port     : %d", port);
    RTMP_Log(RTMP_LOGDEBUG, "Playpath : %s", playpath->av_val);

    if (tcUrl && tcUrl->av_val)
        RTMP_Log(RTMP_LOGDEBUG, "tcUrl    : %s", tcUrl->av_val);
    if (swfUrl && swfUrl->av_val)
        RTMP_Log(RTMP_LOGDEBUG, "swfUrl   : %s", swfUrl->av_val);
    if (pageUrl && pageUrl->av_val)
        RTMP_Log(RTMP_LOGDEBUG, "pageUrl  : %s", pageUrl->av_val);
    if (app && app->av_val)
        RTMP_Log(RTMP_LOGDEBUG, "app      : %.*s", app->av_len, app->av_val);
    if (auth && auth->av_val)
        RTMP_Log(RTMP_LOGDEBUG, "auth     : %s", auth->av_val);
    if (subscribepath && subscribepath->av_val)
        RTMP_Log(RTMP_LOGDEBUG, "subscribepath : %s", subscribepath->av_val);
    if (flashVer && flashVer->av_val)
        RTMP_Log(RTMP_LOGDEBUG, "flashVer : %s", flashVer->av_val);
    if (dStart > 0)
        RTMP_Log(RTMP_LOGDEBUG, "StartTime     : %d msec", dStart);
    if (dStop > 0)
        RTMP_Log(RTMP_LOGDEBUG, "StopTime      : %d msec", dStop);

    RTMP_Log(RTMP_LOGDEBUG, "live     : %s", bLiveStream ? "yes" : "no");
    RTMP_Log(RTMP_LOGDEBUG, "timeout  : %d sec", timeout);

#ifdef CRYPTO
    if (swfSHA256Hash != NULL && swfSize > 0) {
        memcpy(r->Link.SWFHash, swfSHA256Hash->av_val, sizeof(r->Link.SWFHash));
        r->Link.SWFSize = swfSize;
        RTMP_Log(RTMP_LOGDEBUG, "SWFSHA256:");
        RTMP_LogHex(RTMP_LOGDEBUG, r->Link.SWFHash, sizeof(r->Link.SWFHash));
        RTMP_Log(RTMP_LOGDEBUG, "SWFSize  : %lu", r->Link.SWFSize);
    } else {
        r->Link.SWFSize = 0;
    }
#endif

    if (sockshost->av_len) {
        const char *socksport = strchr(sockshost->av_val, ':');
        char *hostname = strdup(sockshost->av_val);

        if (socksport)
            hostname[socksport - sockshost->av_val] = '\0';
        r->Link.sockshost.av_val = hostname;
        r->Link.sockshost.av_len = strlen(hostname);

        r->Link.socksport = socksport ? atoi(socksport + 1) : 1080;
        RTMP_Log(RTMP_LOGDEBUG, "Connecting via SOCKS proxy: %s:%d", r->Link.sockshost.av_val,
                 r->Link.socksport);
    } else {
        r->Link.sockshost.av_val = NULL;
        r->Link.sockshost.av_len = 0;
        r->Link.socksport = 0;
    }

    if (tcUrl && tcUrl->av_len)
        r->Link.tcUrl = *tcUrl;
    if (swfUrl && swfUrl->av_len)
        r->Link.swfUrl = *swfUrl;
    if (pageUrl && pageUrl->av_len)
        r->Link.pageUrl = *pageUrl;
    if (app && app->av_len)
        r->Link.app = *app;
    if (auth && auth->av_len) {
        r->Link.auth = *auth;
        r->Link.lFlags |= RTMP_LF_AUTH;
    }
    if (flashVer && flashVer->av_len)
        r->Link.flashVer = *flashVer;
    else
        r->Link.flashVer = RTMP_DefaultFlashVer;
    if (subscribepath && subscribepath->av_len)
        r->Link.subscribepath = *subscribepath;
    r->Link.seekTime = dStart;
    r->Link.stopTime = dStop;
    if (bLiveStream)
        r->Link.lFlags |= RTMP_LF_LIVE;
    r->Link.timeout = timeout;

    r->Link.protocol = protocol;
    r->Link.hostname = *host;
    r->Link.port = port;
    r->Link.playpath = *playpath;

    if (r->Link.port == 0) {
        if (protocol & RTMP_FEATURE_SSL)
            r->Link.port = 443;
        else if (protocol & RTMP_FEATURE_HTTP)
            r->Link.port = 80;
        else
            r->Link.port = 1935;
    }
}

enum { OPT_STR = 0,
       OPT_INT,
       OPT_BOOL,
       OPT_CONN };
static const char *optinfo[] = {
    "string", "integer", "boolean", "AMF"};

#define OFF(x) offsetof(struct PILI_RTMP, x)

static struct urlopt {
    AVal name;
    off_t off;
    int otype;
    int omisc;
    char *use;
} options[] = {
    {AVC("socks"), OFF(Link.sockshost), OPT_STR, 0,
     "Use the specified SOCKS proxy"},
    {AVC("app"), OFF(Link.app), OPT_STR, 0,
     "Name of target app on server"},
    {AVC("tcUrl"), OFF(Link.tcUrl), OPT_STR, 0,
     "URL to played stream"},
    {AVC("pageUrl"), OFF(Link.pageUrl), OPT_STR, 0,
     "URL of played media's web page"},
    {AVC("swfUrl"), OFF(Link.swfUrl), OPT_STR, 0,
     "URL to player SWF file"},
    {AVC("flashver"), OFF(Link.flashVer), OPT_STR, 0,
     "Flash version string (default " DEF_VERSTR ")"},
    {AVC("conn"), OFF(Link.extras), OPT_CONN, 0,
     "Append arbitrary AMF data to Connect message"},
    {AVC("playpath"), OFF(Link.playpath), OPT_STR, 0,
     "Path to target media on server"},
    {AVC("playlist"), OFF(Link.lFlags), OPT_BOOL, RTMP_LF_PLST,
     "Set playlist before play command"},
    {AVC("live"), OFF(Link.lFlags), OPT_BOOL, RTMP_LF_LIVE,
     "Stream is live, no seeking possible"},
    {AVC("subscribe"), OFF(Link.subscribepath), OPT_STR, 0,
     "Stream to subscribe to"},
    {AVC("token"), OFF(Link.token), OPT_STR, 0,
     "Key for SecureToken response"},
    {AVC("swfVfy"), OFF(Link.lFlags), OPT_BOOL, RTMP_LF_SWFV,
     "Perform SWF Verification"},
    {AVC("swfAge"), OFF(Link.swfAge), OPT_INT, 0,
     "Number of days to use cached SWF hash"},
    {AVC("start"), OFF(Link.seekTime), OPT_INT, 0,
     "Stream start position in milliseconds"},
    {AVC("stop"), OFF(Link.stopTime), OPT_INT, 0,
     "Stream stop position in milliseconds"},
    {AVC("buffer"), OFF(m_nBufferMS), OPT_INT, 0,
     "Buffer time in milliseconds"},
    {AVC("timeout"), OFF(Link.timeout), OPT_INT, 0,
     "Session timeout in seconds"},
    {{NULL, 0}, 0, 0}};

static const AVal truth[] = {
    AVC("1"),
    AVC("on"),
    AVC("yes"),
    AVC("true"),
    {0, 0}};

static void RTMP_OptUsage() {
    int i;

    RTMP_Log(RTMP_LOGERROR, "Valid PILI_RTMP options are:\n");
    for (i = 0; options[i].name.av_len; i++) {
        RTMP_Log(RTMP_LOGERROR, "%10s %-7s  %s\n", options[i].name.av_val,
                 optinfo[options[i].otype], options[i].use);
    }
}

static int
    parseAMF(AMFObject *obj, AVal *av, int *depth) {
    AMFObjectProperty prop = {{0, 0}};
    int i;
    char *p, *arg = av->av_val;

    if (arg[1] == ':') {
        p = (char *)arg + 2;
        switch (arg[0]) {
            case 'B':
                prop.p_type = AMF_BOOLEAN;
                prop.p_vu.p_number = atoi(p);
                break;
            case 'S':
                prop.p_type = AMF_STRING;
                prop.p_vu.p_aval.av_val = p;
                prop.p_vu.p_aval.av_len = av->av_len - (p - arg);
                break;
            case 'N':
                prop.p_type = AMF_NUMBER;
                prop.p_vu.p_number = strtod(p, NULL);
                break;
            case 'Z':
                prop.p_type = AMF_NULL;
                break;
            case 'O':
                i = atoi(p);
                if (i) {
                    prop.p_type = AMF_OBJECT;
                } else {
                    (*depth)--;
                    return 0;
                }
                break;
            default:
                return -1;
        }
    } else if (arg[2] == ':' && arg[0] == 'N') {
        p = strchr(arg + 3, ':');
        if (!p || !*depth)
            return -1;
        prop.p_name.av_val = (char *)arg + 3;
        prop.p_name.av_len = p - (arg + 3);

        p++;
        switch (arg[1]) {
            case 'B':
                prop.p_type = AMF_BOOLEAN;
                prop.p_vu.p_number = atoi(p);
                break;
            case 'S':
                prop.p_type = AMF_STRING;
                prop.p_vu.p_aval.av_val = p;
                prop.p_vu.p_aval.av_len = av->av_len - (p - arg);
                break;
            case 'N':
                prop.p_type = AMF_NUMBER;
                prop.p_vu.p_number = strtod(p, NULL);
                break;
            case 'O':
                prop.p_type = AMF_OBJECT;
                break;
            default:
                return -1;
        }
    } else
        return -1;

    if (*depth) {
        AMFObject *o2;
        for (i = 0; i < *depth; i++) {
            o2 = &obj->o_props[obj->o_num - 1].p_vu.p_object;
            obj = o2;
        }
    }
    AMF_AddProp(obj, &prop);
    if (prop.p_type == AMF_OBJECT)
        (*depth)++;
    return 0;
}

int RTMP_SetOpt(PILI_RTMP *r, const AVal *opt, AVal *arg, RTMPError *error) {
    int i;
    void *v;

    for (i = 0; options[i].name.av_len; i++) {
        if (opt->av_len != options[i].name.av_len) continue;
        if (strcasecmp(opt->av_val, options[i].name.av_val)) continue;
        v = (char *)r + options[i].off;
        switch (options[i].otype) {
            case OPT_STR: {
                AVal *aptr = v;
                *aptr = *arg;
            } break;
            case OPT_INT: {
                long l = strtol(arg->av_val, NULL, 0);
                *(int *)v = l;
            } break;
            case OPT_BOOL: {
                int j, fl;
                fl = *(int *)v;
                for (j = 0; truth[j].av_len; j++) {
                    if (arg->av_len != truth[j].av_len) continue;
                    if (strcasecmp(arg->av_val, truth[j].av_val)) continue;
                    fl |= options[i].omisc;
                    break;
                }
                *(int *)v = fl;
            } break;
            case OPT_CONN:
                if (parseAMF(&r->Link.extras, arg, &r->Link.edepth))
                    return FALSE;
                break;
        }
        break;
    }
    if (!options[i].name.av_len) {
        if (error) {
            char msg[100];
            memset(msg, 0, 100);
            strcat(msg, "Unknown option ");
            strcat(msg, opt->av_val);
            RTMPError_Alloc(error, strlen(msg));
            error->code = RTMPErrorUnknowOption;
            strcpy(error->message, msg);
        }

        RTMP_Log(RTMP_LOGERROR, "Unknown option %s", opt->av_val);
        RTMP_OptUsage();
        return FALSE;
    }

    return TRUE;
}

int PILI_RTMP_SetupURL(PILI_RTMP *r, const char *url, RTMPError *error) {
    AVal opt, arg;
    char *p1, *p2, *ptr = strchr(url, ' ');
    int ret, len;
    unsigned int port = 0;

    if (ptr)
        *ptr = '\0';

    len = (int)strlen(url);
    ret = PILI_RTMP_ParseURL2(url, &r->Link.protocol, &r->Link.hostname,
                              &port, &r->Link.playpath0, &r->Link.app, &r->Link.domain);
    if (!ret)
        return ret;
    r->Link.port = port;
    r->Link.playpath = r->Link.playpath0;

    while (ptr) {
        *ptr++ = '\0';
        p1 = ptr;
        p2 = strchr(p1, '=');
        if (!p2)
            break;
        opt.av_val = p1;
        opt.av_len = p2 - p1;
        *p2++ = '\0';
        arg.av_val = p2;
        ptr = strchr(p2, ' ');
        if (ptr) {
            *ptr = '\0';
            arg.av_len = ptr - p2;
            /* skip repeated spaces */
            while (ptr[1] == ' ')
                *ptr++ = '\0';
        } else {
            arg.av_len = strlen(p2);
        }

        /* unescape */
        port = arg.av_len;
        for (p1 = p2; port > 0;) {
            if (*p1 == '\\') {
                unsigned int c;
                if (port < 3)
                    return FALSE;
                sscanf(p1 + 1, "%02x", &c);
                *p2++ = c;
                port -= 3;
                p1 += 3;
            } else {
                *p2++ = *p1++;
                port--;
            }
        }
        arg.av_len = p2 - arg.av_val;

        ret = RTMP_SetOpt(r, &opt, &arg, error);
        if (!ret)
            return ret;
    }

    if (!r->Link.tcUrl.av_len) {
        r->Link.tcUrl.av_val = url;
        if (r->Link.app.av_len) {
            AVal *domain = &r->Link.domain;
            if (domain->av_len == 0 && r->Link.app.av_val < url + len) {
                /* if app is part of original url, just use it */
                r->Link.tcUrl.av_len = r->Link.app.av_len + (r->Link.app.av_val - url);
            } else {
                if (domain->av_len == 0) {
                    domain = &r->Link.hostname;
                }
                if (r->Link.port = 0) {
                    r->Link.port = 1935;
                }
                len = domain->av_len + r->Link.app.av_len + sizeof("rtmpte://:65535/");
                r->Link.tcUrl.av_val = malloc(len);
                r->Link.tcUrl.av_len = snprintf(r->Link.tcUrl.av_val, len,
                                                "%s://%.*s:%d/%.*s",
                                                PILI_RTMPProtocolStringsLower[r->Link.protocol],
                                                domain->av_len, domain->av_val,
                                                r->Link.port,
                                                r->Link.app.av_len, r->Link.app.av_val);
                r->Link.lFlags |= RTMP_LF_FTCU;
            }
        } else {
            r->Link.tcUrl.av_len = strlen(url);
        }
    }

#ifdef CRYPTO
    if ((r->Link.lFlags & RTMP_LF_SWFV) && r->Link.swfUrl.av_len)
        RTMP_HashSWF(r->Link.swfUrl.av_val, &r->Link.SWFSize,
                     (unsigned char *)r->Link.SWFHash, r->Link.swfAge);
#endif

    if (r->Link.port == 0) {
        if (r->Link.protocol & RTMP_FEATURE_SSL)
            r->Link.port = 443;
        else if (r->Link.protocol & RTMP_FEATURE_HTTP)
            r->Link.port = 80;
        else
            r->Link.port = 1935;
    }
    return TRUE;
}

static int add_addr_info(PILI_RTMP *r, struct addrinfo *hints, struct addrinfo **ai, AVal *host, int port, RTMPError *error) {
    char *hostname;
    int ret = TRUE;
    if (host->av_val[host->av_len]) {
        hostname = malloc(host->av_len + 1);
        memcpy(hostname, host->av_val, host->av_len);
        hostname[host->av_len] = '\0';
    } else {
        hostname = host->av_val;
    }

    struct addrinfo *cur_ai;
    char portstr[10];
    snprintf(portstr, sizeof(portstr), "%d", port);
    int addrret = getaddrinfo(hostname, portstr, hints, ai);
    if (addrret != 0) {
        char msg[100];
        memset(msg, 0, 100);
        strcat(msg, "Problem accessing the DNS. addr: ");
        strcat(msg, hostname);

        RTMPError_Alloc(error, strlen(msg));
        error->code = RTMPErrorAccessDNSFailed;
        strcpy(error->message, msg);
        RTMP_Log(RTMP_LOGERROR, "Problem accessing the DNS. (addr: %s)", hostname);
        ret = FALSE;
    }

    if (hostname != host->av_val) {
        free(hostname);
    }
    return ret;
}

int PILI_RTMP_Connect0(PILI_RTMP *r, struct addrinfo *ai, unsigned short port, RTMPError *error) {
    r->m_sb.sb_timedout = FALSE;
    r->m_pausing = 0;
    r->m_fDuration = 0.0;

    r->m_sb.sb_socket = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
    if (ai->ai_family == AF_INET6) {
        struct sockaddr_in6 *in6 = (struct sockaddr_in6 *)ai->ai_addr;
        in6->sin6_port = htons(port);
    }
    if (r->m_sb.sb_socket != -1) {
        if (connect(r->m_sb.sb_socket, ai->ai_addr, ai->ai_addrlen) < 0) {
            int err = GetSockError();

            if (error) {
                char msg[100];
                memset(msg, 0, 100);
                strcat(msg, "Failed to connect socket. ");
                strcat(msg, strerror(err));
                RTMPError_Alloc(error, strlen(msg));
                error->code = RTMPErrorFailedToConnectSocket;
                strcpy(error->message, msg);
            }

            RTMP_Log(RTMP_LOGERROR, "%s, failed to connect socket. %d (%s)",
                     __FUNCTION__, err, strerror(err));

            PILI_RTMP_Close(r, NULL);
            return FALSE;
        }

        if (r->Link.socksport) {
            RTMP_Log(RTMP_LOGDEBUG, "%s ... SOCKS negotiation", __FUNCTION__);
            if (!SocksNegotiate(r, error)) {
                if (error) {
                    char msg[100];
                    memset(msg, 0, 100);
                    strcat(msg, "Socks negotiation failed.");
                    RTMPError_Alloc(error, strlen(msg));
                    error->code = RTMPErrorSocksNegotiationFailed;
                    strcpy(error->message, msg);
                }

                RTMP_Log(RTMP_LOGERROR, "%s, SOCKS negotiation failed.", __FUNCTION__);
                PILI_RTMP_Close(r, NULL);
                return FALSE;
            }
        }
    } else {
        int err = GetSockError();

        if (error) {
            char msg[100];
            memset(msg, 0, 100);
            strcat(msg, "Failed to create socket. ");
            strcat(msg, strerror(err));
            RTMPError_Alloc(error, strlen(msg));
            error->code = RTMPErrorFailedToCreateSocket;
            strcpy(error->message, msg);
        }

        RTMP_Log(RTMP_LOGERROR, "%s, failed to create socket. Error: %d (%s)", __FUNCTION__, err, strerror(err));

        return FALSE;
    }

    /* set receive timeout */
    {
        SET_RCVTIMEO(tv, r->Link.timeout);
        if (setsockopt(r->m_sb.sb_socket, SOL_SOCKET, SO_RCVTIMEO, (char *)&tv, sizeof(tv))) {
            RTMP_Log(RTMP_LOGERROR, "%s, Setting socket recieve timeout to %ds failed!",
                     __FUNCTION__, r->Link.timeout);
        }
    }

    /* set send timeout*/
    {
        struct timeval timeout;
        timeout.tv_sec = r->Link.send_timeout;
        timeout.tv_usec = 0;

        if (setsockopt(r->m_sb.sb_socket, SOL_SOCKET, SO_SNDTIMEO, (char *)&timeout, sizeof(timeout))) {
            RTMP_Log(RTMP_LOGERROR, "%s, Setting socket send timeout to %ds failed!",
                     __FUNCTION__, r->Link.timeout);
        }
    }

    /* ignore sigpipe */
    int kOne = 1;
#ifdef __linux
    setsockopt(r->m_sb.sb_socket, SOL_SOCKET, MSG_NOSIGNAL, &kOne, sizeof(kOne));
#else
    setsockopt(r->m_sb.sb_socket, SOL_SOCKET, SO_NOSIGPIPE, &kOne, sizeof(kOne));
#endif
    if (r->m_tcp_nodelay) {
        int on = 1;
        setsockopt(r->m_sb.sb_socket, IPPROTO_TCP, TCP_NODELAY, (char *)&on, sizeof(on));
    }

    return TRUE;
}

int PILI_RTMP_Connect1(PILI_RTMP *r, PILI_RTMPPacket *cp, RTMPError *error) {
    if (r->Link.protocol & RTMP_FEATURE_SSL) {
#if defined(CRYPTO) && !defined(NO_SSL)
        TLS_client(RTMP_TLS_ctx, r->m_sb.sb_ssl);
        TLS_setfd(r->m_sb.sb_ssl, r->m_sb.sb_socket);
        if (TLS_connect(r->m_sb.sb_ssl) < 0) {
            if (error) {
                char msg[100];
                memset(msg, 0, 100);
                strcat(msg, "TLS_Connect failed.");
                RTMPError_Alloc(error, strlen(msg));
                error->code = RTMPErrorTLSConnectFailed;
                strcpy(error->message, msg);
            }

            RTMP_Log(RTMP_LOGERROR, "%s, TLS_Connect failed", __FUNCTION__);
            RTMP_Close(r, NULL);
            return FALSE;
        }
#else
        if (error) {
            char msg[100];
            memset(msg, 0, 100);
            strcat(msg, "No SSL/TLS support.");
            RTMPError_Alloc(error, strlen(msg));
            error->code = RTMPErrorNoSSLOrTLSSupport;
            strcpy(error->message, msg);
        }

        RTMP_Log(RTMP_LOGERROR, "%s, no SSL/TLS support", __FUNCTION__);
        PILI_RTMP_Close(r, NULL);
        return FALSE;

#endif
    }
    if (r->Link.protocol & RTMP_FEATURE_HTTP) {
        r->m_msgCounter = 1;
        r->m_clientID.av_val = NULL;
        r->m_clientID.av_len = 0;
        HTTP_Post(r, RTMPT_OPEN, "", 1);
        HTTP_read(r, 1);
        r->m_msgCounter = 0;
    }
    RTMP_Log(RTMP_LOGDEBUG, "%s, ... connected, handshaking", __FUNCTION__);
    if (!HandShake(r, TRUE, error)) {
        if (error) {
            char msg[100];
            memset(msg, 0, 100);
            strcat(msg, "Handshake failed.");
            RTMPError_Alloc(error, strlen(msg));
            error->code = RTMPErrorHandshakeFailed;
            strcpy(error->message, msg);
        }

        RTMP_Log(RTMP_LOGERROR, "%s, handshake failed.", __FUNCTION__);
        PILI_RTMP_Close(r, NULL);
        return FALSE;
    }
    RTMP_Log(RTMP_LOGDEBUG, "%s, handshaked", __FUNCTION__);

    if (!SendConnectPacket(r, cp, error)) {
        if (error) {
            char msg[100];
            memset(msg, 0, 100);
            strcat(msg, "PILI_RTMP connect failed.");
            RTMPError_Alloc(error, strlen(msg));
            error->code = RTMPErrorRTMPConnectFailed;
            strcpy(error->message, msg);
        }
        RTMP_Log(RTMP_LOGERROR, "%s, PILI_RTMP connect failed.", __FUNCTION__);
        PILI_RTMP_Close(r, NULL);
        return FALSE;
    }
    return TRUE;
}

int PILI_RTMP_Connect(PILI_RTMP *r, PILI_RTMPPacket *cp, RTMPError *error) {
    struct PILI_CONNECTION_TIME conn_time;
    if (!r->Link.hostname.av_len)
        return FALSE;

    struct addrinfo hints = {0}, *ai, *cur_ai;
    hints.ai_family = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_DEFAULT;
    unsigned short port;
    if (r->Link.socksport) {
        port = r->Link.socksport;
        /* Connect via SOCKS */
        if (!add_addr_info(r, &hints, &ai, &r->Link.sockshost, r->Link.socksport, error)) {
            return FALSE;
        }
    } else {
        port = r->Link.port;
        /* Connect directly */
        if (!add_addr_info(r, &hints, &ai, &r->Link.hostname, r->Link.port, error)) {
            return FALSE;
        }
    }
    r->ip = 0; //useless for ipv6
    cur_ai = ai;
    
    // parse ip address
    inet_ntop(AF_INET, &(((struct sockaddr_in *)(cur_ai->ai_addr))->sin_addr), r->ipstr, 16);

    int t1 = PILI_RTMP_GetTime();
    if (!PILI_RTMP_Connect0(r, cur_ai, port, error)) {
        freeaddrinfo(ai);
        return FALSE;
    }
    conn_time.connect_time = PILI_RTMP_GetTime() - t1;
    r->m_bSendCounter = TRUE;

    int t2 = PILI_RTMP_GetTime();
    int ret = PILI_RTMP_Connect1(r, cp, error);
    conn_time.handshake_time = PILI_RTMP_GetTime() - t2;

    if (r->m_connCallback != NULL) {
        r->m_connCallback(&conn_time, r->m_userData);
    }
    freeaddrinfo(ai);
    return ret;
}

//useless
static int
    SocksNegotiate(PILI_RTMP *r, RTMPError *error) {
    //  unsigned long addr;
    //  struct sockaddr_in service;
    //  memset(&service, 0, sizeof(struct sockaddr_in));
    //
    //  add_addr_info(r, &service, &r->Link.hostname, r->Link.port, error);
    //  addr = htonl(service.sin_addr.s_addr);
    //
    //  {
    //    char packet[] = {
    //      4, 1,			/* SOCKS 4, connect */
    //      (r->Link.port >> 8) & 0xFF,
    //      (r->Link.port) & 0xFF,
    //      (char)(addr >> 24) & 0xFF, (char)(addr >> 16) & 0xFF,
    //      (char)(addr >> 8) & 0xFF, (char)addr & 0xFF,
    //      0
    //    };				/* NULL terminate */
    //
    //    WriteN(r, packet, sizeof packet, error);
    //
    //    if (ReadN(r, packet, 8) != 8)
    //      return FALSE;
    //
    //    if (packet[0] == 0 && packet[1] == 90)
    //      {
    //        return TRUE;
    //      }
    //    else
    //      {
    //        RTMP_Log(RTMP_LOGERROR, "%s, SOCKS returned error code %d", packet[1]);
    //        return FALSE;
    //      }
    //  }
    return 0;
}

int PILI_RTMP_ConnectStream(PILI_RTMP *r, int seekTime, RTMPError *error) {
    PILI_RTMPPacket packet = {0};

    /* seekTime was already set by SetupStream / SetupURL.
   * This is only needed by ReconnectStream.
   */
    if (seekTime > 0)
        r->Link.seekTime = seekTime;

    r->m_mediaChannel = 0;

    while (!r->m_bPlaying && PILI_RTMP_IsConnected(r) && PILI_RTMP_ReadPacket(r, &packet)) {
        if (RTMPPacket_IsReady(&packet)) {
            if (!packet.m_nBodySize)
                continue;
            if ((packet.m_packetType == RTMP_PACKET_TYPE_AUDIO) ||
                (packet.m_packetType == RTMP_PACKET_TYPE_VIDEO) ||
                (packet.m_packetType == RTMP_PACKET_TYPE_INFO)) {
                RTMP_Log(RTMP_LOGWARNING, "Received FLV packet before play()! Ignoring.");
                PILI_RTMPPacket_Free(&packet);
                continue;
            }

            PILI_RTMP_ClientPacket(r, &packet);
            PILI_RTMPPacket_Free(&packet);
        }
    }

    if (!r->m_bPlaying && error) {
        char *msg = "PILI_RTMP connect stream failed.";
        RTMPError_Alloc(error, strlen(msg));
        error->code = RTMPErrorRTMPConnectStreamFailed;
        strcpy(error->message, msg);
    }

    return r->m_bPlaying;
}

int PILI_RTMP_ReconnectStream(PILI_RTMP *r, int seekTime, RTMPError *error) {
    PILI_RTMP_DeleteStream(r, error);

    PILI_RTMP_SendCreateStream(r, error);

    return PILI_RTMP_ConnectStream(r, seekTime, error);
}

int PILI_RTMP_ToggleStream(PILI_RTMP *r, RTMPError *error) {
    int res;

    if (!r->m_pausing) {
        res = PILI_RTMP_SendPause(r, TRUE, r->m_pauseStamp, error);
        if (!res)
            return res;

        r->m_pausing = 1;
        sleep(1);
    }
    res = PILI_RTMP_SendPause(r, FALSE, r->m_pauseStamp, error);
    r->m_pausing = 3;
    return res;
}

void PILI_RTMP_DeleteStream(PILI_RTMP *r, RTMPError *error) {
    if (r->m_stream_id < 0)
        return;

    r->m_bPlaying = FALSE;

    SendDeleteStream(r, r->m_stream_id, error);
    r->m_stream_id = -1;
}

int PILI_RTMP_GetNextMediaPacket(PILI_RTMP *r, PILI_RTMPPacket *packet) {
    int bHasMediaPacket = 0;

    while (!bHasMediaPacket && PILI_RTMP_IsConnected(r) && PILI_RTMP_ReadPacket(r, packet)) {
        if (!RTMPPacket_IsReady(packet)) {
            continue;
        }

        bHasMediaPacket = PILI_RTMP_ClientPacket(r, packet);

        if (!bHasMediaPacket) {
            PILI_RTMPPacket_Free(packet);
        } else if (r->m_pausing == 3) {
            if (packet->m_nTimeStamp <= r->m_mediaStamp) {
                bHasMediaPacket = 0;
#ifdef _DEBUG
                RTMP_Log(RTMP_LOGDEBUG,
                         "Skipped type: %02X, size: %d, TS: %d ms, abs TS: %d, pause: %d ms",
                         packet->m_packetType, packet->m_nBodySize,
                         packet->m_nTimeStamp, packet->m_hasAbsTimestamp,
                         r->m_mediaStamp);
#endif
                continue;
            }
            r->m_pausing = 0;
        }
    }

    if (bHasMediaPacket)
        r->m_bPlaying = TRUE;
    else if (r->m_sb.sb_timedout && !r->m_pausing)
        r->m_pauseStamp = r->m_channelTimestamp[r->m_mediaChannel];

    return bHasMediaPacket;
}

int PILI_RTMP_ClientPacket(PILI_RTMP *r, PILI_RTMPPacket *packet) {
    int bHasMediaPacket = 0;
    switch (packet->m_packetType) {
        case 0x01:
            /* chunk size */
            HandleChangeChunkSize(r, packet);
            break;

        case 0x03:
            /* bytes read report */
            RTMP_Log(RTMP_LOGDEBUG, "%s, received: bytes read report", __FUNCTION__);
            break;

        case 0x04:
            /* ctrl */
            HandleCtrl(r, packet);
            break;

        case 0x05:
            /* server bw */
            HandleServerBW(r, packet);
            break;

        case 0x06:
            /* client bw */
            HandleClientBW(r, packet);
            break;

        case 0x08:
            /* audio data */
            /*RTMP_Log(RTMP_LOGDEBUG, "%s, received: audio %lu bytes", __FUNCTION__, packet.m_nBodySize); */
            HandleAudio(r, packet);
            bHasMediaPacket = 1;
            if (!r->m_mediaChannel)
                r->m_mediaChannel = packet->m_nChannel;
            if (!r->m_pausing)
                r->m_mediaStamp = packet->m_nTimeStamp;
            break;

        case 0x09:
            /* video data */
            /*RTMP_Log(RTMP_LOGDEBUG, "%s, received: video %lu bytes", __FUNCTION__, packet.m_nBodySize); */
            HandleVideo(r, packet);
            bHasMediaPacket = 1;
            if (!r->m_mediaChannel)
                r->m_mediaChannel = packet->m_nChannel;
            if (!r->m_pausing)
                r->m_mediaStamp = packet->m_nTimeStamp;
            break;

        case 0x0F: /* flex stream send */
            RTMP_Log(RTMP_LOGDEBUG,
                     "%s, flex stream send, size %lu bytes, not supported, ignoring",
                     __FUNCTION__, packet->m_nBodySize);
            break;

        case 0x10: /* flex shared object */
            RTMP_Log(RTMP_LOGDEBUG,
                     "%s, flex shared object, size %lu bytes, not supported, ignoring",
                     __FUNCTION__, packet->m_nBodySize);
            break;

        case 0x11: /* flex message */
        {
            RTMP_Log(RTMP_LOGDEBUG,
                     "%s, flex message, size %lu bytes, not fully supported",
                     __FUNCTION__, packet->m_nBodySize);
/*RTMP_LogHex(packet.m_body, packet.m_nBodySize); */

/* some DEBUG code */
#if 0
	   RTMP_LIB_AMFObject obj;
	   int nRes = obj.Decode(packet.m_body+1, packet.m_nBodySize-1);
	   if(nRes < 0) {
	   RTMP_Log(RTMP_LOGERROR, "%s, error decoding AMF3 packet", __FUNCTION__);
	   /*return; */
	   }

	   obj.Dump();
#endif

            if (HandleInvoke(r, packet->m_body + 1, packet->m_nBodySize - 1) == 1)
                bHasMediaPacket = 2;
            break;
        }
        case 0x12:
            /* metadata (notify) */
            RTMP_Log(RTMP_LOGDEBUG, "%s, received: notify %lu bytes", __FUNCTION__,
                     packet->m_nBodySize);
            if (HandleMetadata(r, packet->m_body, packet->m_nBodySize))
                bHasMediaPacket = 1;
            break;

        case 0x13:
            RTMP_Log(RTMP_LOGDEBUG, "%s, shared object, not supported, ignoring",
                     __FUNCTION__);
            break;

        case 0x14:
            /* invoke */
            RTMP_Log(RTMP_LOGDEBUG, "%s, received: invoke %lu bytes", __FUNCTION__,
                     packet->m_nBodySize);
            /*RTMP_LogHex(packet.m_body, packet.m_nBodySize); */

            if (HandleInvoke(r, packet->m_body, packet->m_nBodySize) == 1)
                bHasMediaPacket = 2;
            break;

        case 0x16: {
            /* go through FLV packets and handle metadata packets */
            unsigned int pos = 0;
            uint32_t nTimeStamp = packet->m_nTimeStamp;

            while (pos + 11 < packet->m_nBodySize) {
                uint32_t dataSize = AMF_DecodeInt24(packet->m_body + pos + 1); /* size without header (11) and prevTagSize (4) */

                if (pos + 11 + dataSize + 4 > packet->m_nBodySize) {
                    RTMP_Log(RTMP_LOGWARNING, "Stream corrupt?!");
                    break;
                }
                if (packet->m_body[pos] == 0x12) {
                    HandleMetadata(r, packet->m_body + pos + 11, dataSize);
                } else if (packet->m_body[pos] == 8 || packet->m_body[pos] == 9) {
                    nTimeStamp = AMF_DecodeInt24(packet->m_body + pos + 4);
                    nTimeStamp |= (packet->m_body[pos + 7] << 24);
                }
                pos += (11 + dataSize + 4);
            }
            if (!r->m_pausing)
                r->m_mediaStamp = nTimeStamp;

            /* FLV tag(s) */
            /*RTMP_Log(RTMP_LOGDEBUG, "%s, received: FLV tag(s) %lu bytes", __FUNCTION__, packet.m_nBodySize); */
            bHasMediaPacket = 1;
            break;
        }
        default:
            RTMP_Log(RTMP_LOGDEBUG, "%s, unknown packet type received: 0x%02x", __FUNCTION__,
                     packet->m_packetType);
#ifdef _DEBUG
            RTMP_LogHex(RTMP_LOGDEBUG, packet->m_body, packet->m_nBodySize);
#endif
    }

    return bHasMediaPacket;
}

#ifdef _DEBUG
extern FILE *netstackdump;
extern FILE *netstackdump_read;
#endif

static int
    ReadN(PILI_RTMP *r, char *buffer, int n) {
    int nOriginalSize = n;
    int avail;
    char *ptr;

    r->m_sb.sb_timedout = FALSE;

#ifdef _DEBUG
    memset(buffer, 0, n);
#endif

    ptr = buffer;
    while (n > 0) {
        int nBytes = 0, nRead;
        if (r->Link.protocol & RTMP_FEATURE_HTTP) {
            while (!r->m_resplen) {
                if (r->m_sb.sb_size < 144) {
                    if (!r->m_unackd)
                        HTTP_Post(r, RTMPT_IDLE, "", 1);
                    if (PILI_RTMPSockBuf_Fill(&r->m_sb) < 1) {
                        if (!r->m_sb.sb_timedout) {
                            PILI_RTMP_Close(r, NULL);
                        } else {
                            RTMPError error = {0};

                            char msg[100];
                            memset(msg, 0, 100);
                            strcat(msg, "PILI_RTMP socket timeout");
                            RTMPError_Alloc(&error, strlen(msg));
                            error.code = RTMPErrorSocketTimeout;
                            strcpy(error.message, msg);

                            PILI_RTMP_Close(r, &error);

                            RTMPError_Free(&error);
                        }

                        return 0;
                    }
                }
                HTTP_read(r, 0);
            }
            if (r->m_resplen && !r->m_sb.sb_size)
                PILI_RTMPSockBuf_Fill(&r->m_sb);
            avail = r->m_sb.sb_size;
            if (avail > r->m_resplen)
                avail = r->m_resplen;
        } else {
            avail = r->m_sb.sb_size;
            if (avail == 0) {
                if (PILI_RTMPSockBuf_Fill(&r->m_sb) < 1) {
                    if (!r->m_sb.sb_timedout) {
                        PILI_RTMP_Close(r, NULL);
                    } else {
                        RTMPError error = {0};

                        char msg[100];
                        memset(msg, 0, 100);
                        strcat(msg, "PILI_RTMP socket timeout");
                        RTMPError_Alloc(&error, strlen(msg));
                        error.code = RTMPErrorSocketTimeout;
                        strcpy(error.message, msg);

                        PILI_RTMP_Close(r, &error);

                        RTMPError_Free(&error);
                    }

                    return 0;
                }
                avail = r->m_sb.sb_size;
            }
        }
        nRead = ((n < avail) ? n : avail);
        if (nRead > 0) {
            memcpy(ptr, r->m_sb.sb_start, nRead);
            r->m_sb.sb_start += nRead;
            r->m_sb.sb_size -= nRead;
            nBytes = nRead;
            r->m_nBytesIn += nRead;
            if (r->m_bSendCounter && r->m_nBytesIn > r->m_nBytesInSent + r->m_nClientBW / 2)
                SendBytesReceived(r, NULL);
        }
/*RTMP_Log(RTMP_LOGDEBUG, "%s: %d bytes\n", __FUNCTION__, nBytes); */
#ifdef _DEBUG
        fwrite(ptr, 1, nBytes, netstackdump_read);
#endif

        if (nBytes == 0) {
            RTMP_Log(RTMP_LOGDEBUG, "%s, PILI_RTMP socket closed by peer", __FUNCTION__);
            /*goto again; */
            RTMPError error = {0};

            char msg[100];
            memset(msg, 0, 100);
            strcat(msg, "PILI_RTMP socket closed by peer. ");
            RTMPError_Alloc(&error, strlen(msg));
            error.code = RTMPErrorSocketClosedByPeer;
            strcpy(error.message, msg);

            PILI_RTMP_Close(r, &error);

            RTMPError_Free(&error);
            break;
        }

        if (r->Link.protocol & RTMP_FEATURE_HTTP)
            r->m_resplen -= nBytes;

#ifdef CRYPTO
        if (r->Link.rc4keyIn) {
            RC4_encrypt(r->Link.rc4keyIn, nBytes, ptr);
        }
#endif

        n -= nBytes;
        ptr += nBytes;
    }

    return nOriginalSize - n;
}

static int
    WriteN(PILI_RTMP *r, const char *buffer, int n, RTMPError *error) {
    const char *ptr = buffer;
#ifdef CRYPTO
    char *encrypted = 0;
    char buf[RTMP_BUFFER_CACHE_SIZE];

    if (r->Link.rc4keyOut) {
        if (n > sizeof(buf))
            encrypted = (char *)malloc(n);
        else
            encrypted = (char *)buf;
        ptr = encrypted;
        RC4_encrypt2(r->Link.rc4keyOut, n, buffer, ptr);
    }
#endif

    while (n > 0) {
        int nBytes;

        if (r->Link.protocol & RTMP_FEATURE_HTTP)
            nBytes = HTTP_Post(r, RTMPT_SEND, ptr, n);
        else
            nBytes = PILI_RTMPSockBuf_Send(&r->m_sb, ptr, n);
        /*RTMP_Log(RTMP_LOGDEBUG, "%s: %d\n", __FUNCTION__, nBytes); */

        if (nBytes < 0) {
            int sockerr = GetSockError();
            RTMP_Log(RTMP_LOGERROR, "%s, PILI_RTMP send error %d, %s, (%d bytes)", __FUNCTION__,
                     sockerr, strerror(sockerr), n);

            if (sockerr == EINTR && !PILI_RTMP_ctrlC)
                continue;

            if (error) {
                char msg[100];
                memset(msg, 0, 100);
                strcat(msg, "PILI_RTMP send error. socket error: ");
                strcat(msg, strerror(sockerr));
                RTMPError_Alloc(error, strlen(msg));
                error->code = RTMPErrorSendFailed;
                strcpy(error->message, msg);
            }

            PILI_RTMP_Close(r, error);

            RTMPError_Free(error);

            n = 1;
            break;
        }

        if (nBytes == 0)
            break;

        n -= nBytes;
        ptr += nBytes;
    }

#ifdef CRYPTO
    if (encrypted && encrypted != buf)
        free(encrypted);
#endif

    return n == 0;
}

#define SAVC(x) static const AVal av_##x = AVC(#x)

SAVC(app);
SAVC(connect);
SAVC(flashVer);
SAVC(swfUrl);
SAVC(pageUrl);
SAVC(tcUrl);
SAVC(fpad);
SAVC(capabilities);
SAVC(audioCodecs);
SAVC(videoCodecs);
SAVC(videoFunction);
SAVC(objectEncoding);
SAVC(secureToken);
SAVC(secureTokenResponse);
SAVC(type);
SAVC(nonprivate);

static int
    SendConnectPacket(PILI_RTMP *r, PILI_RTMPPacket *cp, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[4096], *pend = pbuf + sizeof(pbuf);
    char *enc;

    if (cp)
        return PILI_RTMP_SendPacket(r, cp, TRUE, error);

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_connect);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_OBJECT;

    enc = AMF_EncodeNamedString(enc, pend, &av_app, &r->Link.app);
    if (!enc)
        return FALSE;
    if (r->Link.protocol & RTMP_FEATURE_WRITE) {
        enc = AMF_EncodeNamedString(enc, pend, &av_type, &av_nonprivate);
        if (!enc)
            return FALSE;
    }
    if (r->Link.flashVer.av_len) {
        enc = AMF_EncodeNamedString(enc, pend, &av_flashVer, &r->Link.flashVer);
        if (!enc)
            return FALSE;
    }
    if (r->Link.swfUrl.av_len) {
        enc = AMF_EncodeNamedString(enc, pend, &av_swfUrl, &r->Link.swfUrl);
        if (!enc)
            return FALSE;
    }
    if (r->Link.tcUrl.av_len) {
        enc = AMF_EncodeNamedString(enc, pend, &av_tcUrl, &r->Link.tcUrl);
        if (!enc)
            return FALSE;
    }
    if (!(r->Link.protocol & RTMP_FEATURE_WRITE)) {
        enc = AMF_EncodeNamedBoolean(enc, pend, &av_fpad, FALSE);
        if (!enc)
            return FALSE;
        enc = AMF_EncodeNamedNumber(enc, pend, &av_capabilities, 15.0);
        if (!enc)
            return FALSE;
        enc = AMF_EncodeNamedNumber(enc, pend, &av_audioCodecs, r->m_fAudioCodecs);
        if (!enc)
            return FALSE;
        enc = AMF_EncodeNamedNumber(enc, pend, &av_videoCodecs, r->m_fVideoCodecs);
        if (!enc)
            return FALSE;
        enc = AMF_EncodeNamedNumber(enc, pend, &av_videoFunction, 1.0);
        if (!enc)
            return FALSE;
        if (r->Link.pageUrl.av_len) {
            enc = AMF_EncodeNamedString(enc, pend, &av_pageUrl, &r->Link.pageUrl);
            if (!enc)
                return FALSE;
        }
    }
    if (r->m_fEncoding != 0.0 || r->m_bSendEncoding) { /* AMF0, AMF3 not fully supported yet */
        enc = AMF_EncodeNamedNumber(enc, pend, &av_objectEncoding, r->m_fEncoding);
        if (!enc)
            return FALSE;
    }
    if (enc + 3 >= pend)
        return FALSE;
    *enc++ = 0;
    *enc++ = 0; /* end of object - 0x00 0x00 0x09 */
    *enc++ = AMF_OBJECT_END;

    /* add auth string */
    if (r->Link.auth.av_len) {
        enc = AMF_EncodeBoolean(enc, pend, r->Link.lFlags & RTMP_LF_AUTH);
        if (!enc)
            return FALSE;
        enc = AMF_EncodeString(enc, pend, &r->Link.auth);
        if (!enc)
            return FALSE;
    }
    if (r->Link.extras.o_num) {
        int i;
        for (i = 0; i < r->Link.extras.o_num; i++) {
            enc = AMFProp_Encode(&r->Link.extras.o_props[i], enc, pend);
            if (!enc)
                return FALSE;
        }
    }
    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

#if 0 /* unused */
SAVC(bgHasStream);

static int
SendBGHasStream(PILI_RTMP *r, double dId, AVal *playpath)
{
  PILI_RTMPPacket packet;
  char pbuf[1024], *pend = pbuf + sizeof(pbuf);
  char *enc;

  packet.m_nChannel = 0x03;	/* control channel (invoke) */
  packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
  packet.m_packetType = 0x14;	/* INVOKE */
  packet.m_nTimeStamp = 0;
  packet.m_nInfoField2 = 0;
  packet.m_hasAbsTimestamp = 0;
  packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

  enc = packet.m_body;
  enc = AMF_EncodeString(enc, pend, &av_bgHasStream);
  enc = AMF_EncodeNumber(enc, pend, dId);
  *enc++ = AMF_NULL;

  enc = AMF_EncodeString(enc, pend, playpath);
  if (enc == NULL)
    return FALSE;

  packet.m_nBodySize = enc - packet.m_body;

  return PILI_RTMP_SendPacket(r, &packet, TRUE);
}
#endif

SAVC(createStream);

int PILI_RTMP_SendCreateStream(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_createStream);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL; /* NULL */

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

SAVC(FCSubscribe);

static int
    SendFCSubscribe(PILI_RTMP *r, AVal *subscribepath, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[512], *pend = pbuf + sizeof(pbuf);
    char *enc;
    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    RTMP_Log(RTMP_LOGDEBUG, "FCSubscribe: %s", subscribepath->av_val);
    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_FCSubscribe);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeString(enc, pend, subscribepath);

    if (!enc)
        return FALSE;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

SAVC(releaseStream);

static int
    SendReleaseStream(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[1024], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_releaseStream);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeString(enc, pend, &r->Link.playpath);
    if (!enc)
        return FALSE;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(FCPublish);

static int
    SendFCPublish(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[1024], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_FCPublish);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeString(enc, pend, &r->Link.playpath);
    if (!enc)
        return FALSE;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(FCUnpublish);

static int
    SendFCUnpublish(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[1024], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_FCUnpublish);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeString(enc, pend, &r->Link.playpath);
    if (!enc)
        return FALSE;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(publish);
SAVC(live);
SAVC(record);

static int
    SendPublish(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[1024], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x04; /* source channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = r->m_stream_id;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_publish);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeString(enc, pend, &r->Link.playpath);
    if (!enc)
        return FALSE;

    /* FIXME: should we choose live based on Link.lFlags & RTMP_LF_LIVE? */
    enc = AMF_EncodeString(enc, pend, &av_live);
    if (!enc)
        return FALSE;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

SAVC(deleteStream);

static int
    SendDeleteStream(PILI_RTMP *r, double dStreamId, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_deleteStream);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeNumber(enc, pend, dStreamId);

    packet.m_nBodySize = enc - packet.m_body;

    /* no response expected */
    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(pause);

int PILI_RTMP_SendPause(PILI_RTMP *r, int DoPause, int iTime, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x08; /* video channel */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* invoke */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_pause);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeBoolean(enc, pend, DoPause);
    enc = AMF_EncodeNumber(enc, pend, (double)iTime);

    packet.m_nBodySize = enc - packet.m_body;

    RTMP_Log(RTMP_LOGDEBUG, "%s, %d, pauseTime=%d", __FUNCTION__, DoPause, iTime);
    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

int PILI_RTMP_Pause(PILI_RTMP *r, int DoPause, RTMPError *error) {
    if (DoPause)
        r->m_pauseStamp = r->m_channelTimestamp[r->m_mediaChannel];
    return PILI_RTMP_SendPause(r, DoPause, r->m_pauseStamp, error);
}

SAVC(seek);

int PILI_RTMP_SendSeek(PILI_RTMP *r, int iTime, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x08; /* video channel */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* invoke */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_seek);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeNumber(enc, pend, (double)iTime);

    packet.m_nBodySize = enc - packet.m_body;

    r->m_read.flags |= RTMP_READ_SEEKING;
    r->m_read.nResumeTS = 0;

    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

int PILI_RTMP_SendServerBW(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);

    packet.m_nChannel = 0x02; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = 0x05; /* Server BW */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    packet.m_nBodySize = 4;

    AMF_EncodeInt32(packet.m_body, pend, r->m_nServerBW);
    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

int PILI_RTMP_SendClientBW(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);

    packet.m_nChannel = 0x02; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = 0x06; /* Client BW */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    packet.m_nBodySize = 5;

    AMF_EncodeInt32(packet.m_body, pend, r->m_nClientBW);
    packet.m_body[4] = r->m_nClientBW2;
    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

static int
    SendBytesReceived(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);

    packet.m_nChannel = 0x02; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x03; /* bytes in */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    packet.m_nBodySize = 4;

    AMF_EncodeInt32(packet.m_body, pend, r->m_nBytesIn); /* hard coded for now */
    r->m_nBytesInSent = r->m_nBytesIn;

    /*RTMP_Log(RTMP_LOGDEBUG, "Send bytes report. 0x%x (%d bytes)", (unsigned int)m_nBytesIn, m_nBytesIn); */
    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(_checkbw);

static int
    SendCheckBW(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0; /* RTMP_GetTime(); */
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av__checkbw);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;

    packet.m_nBodySize = enc - packet.m_body;

    /* triggers _onbwcheck and eventually results in _onbwdone */
    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(_result);

static int
    SendCheckBWResult(PILI_RTMP *r, double txn, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0x16 * r->m_nBWCheckCounter; /* temp inc value. till we figure it out. */
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av__result);
    enc = AMF_EncodeNumber(enc, pend, txn);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeNumber(enc, pend, (double)r->m_nBWCheckCounter++);

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(ping);
SAVC(pong);

static int
    SendPong(PILI_RTMP *r, double txn, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0x16 * r->m_nBWCheckCounter; /* temp inc value. till we figure it out. */
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_pong);
    enc = AMF_EncodeNumber(enc, pend, txn);
    *enc++ = AMF_NULL;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

SAVC(play);

static int
    SendPlay(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[1024], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x08; /* we make 8 our stream channel */
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = r->m_stream_id; /*0x01000000; */
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_play);
    enc = AMF_EncodeNumber(enc, pend, ++r->m_numInvokes);
    *enc++ = AMF_NULL;

    RTMP_Log(RTMP_LOGDEBUG, "%s, seekTime=%d, stopTime=%d, sending play: %s",
             __FUNCTION__, r->Link.seekTime, r->Link.stopTime,
             r->Link.playpath.av_val);
    enc = AMF_EncodeString(enc, pend, &r->Link.playpath);
    if (!enc)
        return FALSE;

    /* Optional parameters start and len.
   *
   * start: -2, -1, 0, positive number
   *  -2: looks for a live stream, then a recorded stream,
   *      if not found any open a live stream
   *  -1: plays a live stream
   * >=0: plays a recorded streams from 'start' milliseconds
   */
    if (r->Link.lFlags & RTMP_LF_LIVE)
        enc = AMF_EncodeNumber(enc, pend, -1000.0);
    else {
        if (r->Link.seekTime > 0.0)
            enc = AMF_EncodeNumber(enc, pend, r->Link.seekTime); /* resume from here */
        else
            enc = AMF_EncodeNumber(enc, pend, 0.0); /*-2000.0);*/ /* recorded as default, -2000.0 is not reliable since that freezes the player if the stream is not found */
    }
    if (!enc)
        return FALSE;

    /* len: -1, 0, positive number
   *  -1: plays live or recorded stream to the end (default)
   *   0: plays a frame 'start' ms away from the beginning
   *  >0: plays a live or recoded stream for 'len' milliseconds
   */
    /*enc += EncodeNumber(enc, -1.0); */ /* len */
    if (r->Link.stopTime) {
        enc = AMF_EncodeNumber(enc, pend, r->Link.stopTime - r->Link.seekTime);
        if (!enc)
            return FALSE;
    }

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

SAVC(set_playlist);
SAVC(0);

static int
    SendPlaylist(PILI_RTMP *r, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[1024], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x08; /* we make 8 our stream channel */
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = 0x14; /* INVOKE */
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = r->m_stream_id; /*0x01000000; */
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_set_playlist);
    enc = AMF_EncodeNumber(enc, pend, 0);
    *enc++ = AMF_NULL;
    *enc++ = AMF_ECMA_ARRAY;
    *enc++ = 0;
    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT;
    enc = AMF_EncodeNamedString(enc, pend, &av_0, &r->Link.playpath);
    if (!enc)
        return FALSE;
    if (enc + 3 >= pend)
        return FALSE;
    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT_END;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, TRUE, error);
}

static int
    SendSecureTokenResponse(PILI_RTMP *r, AVal *resp, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[1024], *pend = pbuf + sizeof(pbuf);
    char *enc;

    packet.m_nChannel = 0x03; /* control channel (invoke) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x14;
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_secureTokenResponse);
    enc = AMF_EncodeNumber(enc, pend, 0.0);
    *enc++ = AMF_NULL;
    enc = AMF_EncodeString(enc, pend, resp);
    if (!enc)
        return FALSE;

    packet.m_nBodySize = enc - packet.m_body;

    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

/*
from http://jira.red5.org/confluence/display/docs/Ping:

Ping is the most mysterious message in PILI_RTMP and till now we haven't fully interpreted it yet. In summary, Ping message is used as a special command that are exchanged between client and server. This page aims to document all known Ping messages. Expect the list to grow.

The type of Ping packet is 0x4 and contains two mandatory parameters and two optional parameters. The first parameter is the type of Ping and in short integer. The second parameter is the target of the ping. As Ping is always sent in Channel 2 (control channel) and the target object in PILI_RTMP header is always 0 which means the Connection object, it's necessary to put an extra parameter to indicate the exact target object the Ping is sent to. The second parameter takes this responsibility. The value has the same meaning as the target object field in PILI_RTMP header. (The second value could also be used as other purposes, like RTT Ping/Pong. It is used as the timestamp.) The third and fourth parameters are optional and could be looked upon as the parameter of the Ping packet. Below is an unexhausted list of Ping messages.

    * type 0: Clear the stream. No third and fourth parameters. The second parameter could be 0. After the connection is established, a Ping 0,0 will be sent from server to client. The message will also be sent to client on the start of Play and in response of a Seek or Pause/Resume request. This Ping tells client to re-calibrate the clock with the timestamp of the next packet server sends.
    * type 1: Tell the stream to clear the playing buffer.
    * type 3: Buffer time of the client. The third parameter is the buffer time in millisecond.
    * type 4: Reset a stream. Used together with type 0 in the case of VOD. Often sent before type 0.
    * type 6: Ping the client from server. The second parameter is the current time.
    * type 7: Pong reply from client. The second parameter is the time the server sent with his ping request.
    * type 26: SWFVerification request
    * type 27: SWFVerification response
*/
int PILI_RTMP_SendCtrl(PILI_RTMP *r, short nType, unsigned int nObject, unsigned int nTime, RTMPError *error) {
    PILI_RTMPPacket packet;
    char pbuf[256], *pend = pbuf + sizeof(pbuf);
    int nSize;
    char *buf;

    RTMP_Log(RTMP_LOGDEBUG, "sending ctrl. type: 0x%04x", (unsigned short)nType);

    packet.m_nChannel = 0x02; /* control channel (ping) */
    packet.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    packet.m_packetType = 0x04; /* ctrl */
    packet.m_nTimeStamp = 0; /* RTMP_GetTime(); */
    packet.m_nInfoField2 = 0;
    packet.m_hasAbsTimestamp = 0;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;

    switch (nType) {
        case 0x03:
            nSize = 10;
            break; /* buffer time */
        case 0x1A:
            nSize = 3;
            break; /* SWF verify request */
        case 0x1B:
            nSize = 44;
            break; /* SWF verify response */
        default:
            nSize = 6;
            break;
    }

    packet.m_nBodySize = nSize;

    buf = packet.m_body;
    buf = AMF_EncodeInt16(buf, pend, nType);

    if (nType == 0x1B) {
#ifdef CRYPTO
        memcpy(buf, r->Link.SWFVerificationResponse, 42);
        RTMP_Log(RTMP_LOGDEBUG, "Sending SWFVerification response: ");
        RTMP_LogHex(RTMP_LOGDEBUG, (uint8_t *)packet.m_body, packet.m_nBodySize);
#endif
    } else if (nType == 0x1A) {
        *buf = nObject & 0xff;
    } else {
        if (nSize > 2)
            buf = AMF_EncodeInt32(buf, pend, nObject);

        if (nSize > 6)
            buf = AMF_EncodeInt32(buf, pend, nTime);
    }

    return PILI_RTMP_SendPacket(r, &packet, FALSE, error);
}

static void
    AV_erase(PILI_RTMP_METHOD *vals, int *num, int i, int freeit) {
    if (freeit)
        free(vals[i].name.av_val);
    (*num)--;
    for (; i < *num; i++) {
        vals[i] = vals[i + 1];
    }
    vals[i].name.av_val = NULL;
    vals[i].name.av_len = 0;
    vals[i].num = 0;
}

void PILI_RTMP_DropRequest(PILI_RTMP *r, int i, int freeit) {
    AV_erase(r->m_methodCalls, &r->m_numCalls, i, freeit);
}

static void
    AV_queue(PILI_RTMP_METHOD **vals, int *num, AVal *av, int txn) {
    char *tmp;
    if (!(*num & 0x0f))
        *vals = realloc(*vals, (*num + 16) * sizeof(PILI_RTMP_METHOD));
    tmp = malloc(av->av_len + 1);
    memcpy(tmp, av->av_val, av->av_len);
    tmp[av->av_len] = '\0';
    (*vals)[*num].num = txn;
    (*vals)[*num].name.av_len = av->av_len;
    (*vals)[(*num)++].name.av_val = tmp;
}

static void
    AV_clear(PILI_RTMP_METHOD *vals, int num) {
    int i;
    for (i = 0; i < num; i++)
        free(vals[i].name.av_val);
    free(vals);
}

SAVC(onBWDone);
SAVC(onFCSubscribe);
SAVC(onFCUnsubscribe);
SAVC(_onbwcheck);
SAVC(_onbwdone);
SAVC(_error);
SAVC(close);
SAVC(code);
SAVC(level);
SAVC(onStatus);
SAVC(playlist_ready);
static const AVal av_NetStream_Failed = AVC("NetStream.Failed");
static const AVal av_NetStream_Play_Failed = AVC("NetStream.Play.Failed");
static const AVal av_NetStream_Play_StreamNotFound =
    AVC("NetStream.Play.StreamNotFound");
static const AVal av_NetConnection_Connect_InvalidApp =
    AVC("NetConnection.Connect.InvalidApp");
static const AVal av_NetStream_Play_Start = AVC("NetStream.Play.Start");
static const AVal av_NetStream_Play_Complete = AVC("NetStream.Play.Complete");
static const AVal av_NetStream_Play_Stop = AVC("NetStream.Play.Stop");
static const AVal av_NetStream_Seek_Notify = AVC("NetStream.Seek.Notify");
static const AVal av_NetStream_Pause_Notify = AVC("NetStream.Pause.Notify");
static const AVal av_NetStream_Play_UnpublishNotify =
    AVC("NetStream.Play.UnpublishNotify");
static const AVal av_NetStream_Publish_Start = AVC("NetStream.Publish.Start");

/* Returns 0 for OK/Failed/error, 1 for 'Stop or Complete' */
static int
    HandleInvoke(PILI_RTMP *r, const char *body, unsigned int nBodySize) {
    AMFObject obj;
    AVal method;
    int txn;
    int ret = 0, nRes;
    if (body[0] != 0x02) /* make sure it is a string method name we start with */
    {
        RTMP_Log(RTMP_LOGWARNING, "%s, Sanity failed. no string method in invoke packet",
                 __FUNCTION__);
        return 0;
    }

    nRes = AMF_Decode(&obj, body, nBodySize, FALSE);
    if (nRes < 0) {
        RTMP_Log(RTMP_LOGERROR, "%s, error decoding invoke packet", __FUNCTION__);
        return 0;
    }

    AMF_Dump(&obj);
    AMFProp_GetString(AMF_GetProp(&obj, NULL, 0), &method);
    txn = (int)AMFProp_GetNumber(AMF_GetProp(&obj, NULL, 1));
    RTMP_Log(RTMP_LOGDEBUG, "%s, server invoking <%s>", __FUNCTION__, method.av_val);

    RTMPError error = {0};

    if (AVMATCH(&method, &av__result)) {
        AVal methodInvoked = {0};
        int i;

        for (i = 0; i < r->m_numCalls; i++) {
            if (r->m_methodCalls[i].num == txn) {
                methodInvoked = r->m_methodCalls[i].name;
                AV_erase(r->m_methodCalls, &r->m_numCalls, i, FALSE);
                break;
            }
        }
        if (!methodInvoked.av_val) {
            RTMP_Log(RTMP_LOGDEBUG, "%s, received result id %d without matching request",
                     __FUNCTION__, txn);
            goto leave;
        }

        RTMP_Log(RTMP_LOGDEBUG, "%s, received result for method call <%s>", __FUNCTION__,
                 methodInvoked.av_val);

        if (AVMATCH(&methodInvoked, &av_connect)) {
            if (r->Link.token.av_len) {
                AMFObjectProperty p;
                if (PILI_RTMP_FindFirstMatchingProperty(&obj, &av_secureToken, &p)) {
                    DecodeTEA(&r->Link.token, &p.p_vu.p_aval);
                    SendSecureTokenResponse(r, &p.p_vu.p_aval, &error);
                }
            }
            if (r->Link.protocol & RTMP_FEATURE_WRITE) {
                SendReleaseStream(r, &error);
                SendFCPublish(r, &error);
            } else {
                PILI_RTMP_SendServerBW(r, &error);
                PILI_RTMP_SendCtrl(r, 3, 0, 300, &error);
            }
            PILI_RTMP_SendCreateStream(r, &error);

            if (!(r->Link.protocol & RTMP_FEATURE_WRITE)) {
                /* Send the FCSubscribe if live stream or if subscribepath is set */
                if (r->Link.subscribepath.av_len)
                    SendFCSubscribe(r, &r->Link.subscribepath, &error);
                else if (r->Link.lFlags & RTMP_LF_LIVE)
                    SendFCSubscribe(r, &r->Link.playpath, &error);
            }
        } else if (AVMATCH(&methodInvoked, &av_createStream)) {
            r->m_stream_id = (int)AMFProp_GetNumber(AMF_GetProp(&obj, NULL, 3));

            if (r->Link.protocol & RTMP_FEATURE_WRITE) {
                SendPublish(r, &error);
            } else {
                if (r->Link.lFlags & RTMP_LF_PLST)
                    SendPlaylist(r, &error);
                SendPlay(r, &error);
                PILI_RTMP_SendCtrl(r, 3, r->m_stream_id, r->m_nBufferMS, &error);
            }
        } else if (AVMATCH(&methodInvoked, &av_play) ||
                   AVMATCH(&methodInvoked, &av_publish)) {
            r->m_bPlaying = TRUE;
        }
        free(methodInvoked.av_val);
    } else if (AVMATCH(&method, &av_onBWDone)) {
        if (!r->m_nBWCheckCounter)
            SendCheckBW(r, &error);
    } else if (AVMATCH(&method, &av_onFCSubscribe)) {
        /* SendOnFCSubscribe(); */
    } else if (AVMATCH(&method, &av_onFCUnsubscribe)) {
        PILI_RTMP_Close(r, NULL);
        ret = 1;
    } else if (AVMATCH(&method, &av_ping)) {
        SendPong(r, txn, &error);
    } else if (AVMATCH(&method, &av__onbwcheck)) {
        SendCheckBWResult(r, txn, &error);
    } else if (AVMATCH(&method, &av__onbwdone)) {
        int i;
        for (i = 0; i < r->m_numCalls; i++)
            if (AVMATCH(&r->m_methodCalls[i].name, &av__checkbw)) {
                AV_erase(r->m_methodCalls, &r->m_numCalls, i, TRUE);
                break;
            }
    } else if (AVMATCH(&method, &av__error)) {
        RTMP_Log(RTMP_LOGERROR, "PILI_RTMP server sent error");
    } else if (AVMATCH(&method, &av_close)) {
        RTMP_Log(RTMP_LOGERROR, "PILI_RTMP server requested close");
        RTMPError error = {0};
        char *msg = "PILI_RTMP server requested close.";
        RTMPError_Alloc(&error, strlen(msg));
        error.code = RTMPErrorServerRequestedClose;
        strcpy(error.message, msg);

        PILI_RTMP_Close(r, &error);

        RTMPError_Free(&error);
    } else if (AVMATCH(&method, &av_onStatus)) {
        AMFObject obj2;
        AVal code, level;
        AMFProp_GetObject(AMF_GetProp(&obj, NULL, 3), &obj2);
        AMFProp_GetString(AMF_GetProp(&obj2, &av_code, -1), &code);
        AMFProp_GetString(AMF_GetProp(&obj2, &av_level, -1), &level);

        RTMP_Log(RTMP_LOGDEBUG, "%s, onStatus: %s", __FUNCTION__, code.av_val);
        if (AVMATCH(&code, &av_NetStream_Failed) || AVMATCH(&code, &av_NetStream_Play_Failed) || AVMATCH(&code, &av_NetStream_Play_StreamNotFound) || AVMATCH(&code, &av_NetConnection_Connect_InvalidApp)) {
            r->m_stream_id = -1;

            int err_code;
            char msg[100];
            memset(msg, 0, 100);

            if (AVMATCH(&code, &av_NetStream_Failed)) {
                err_code = RTMPErrorNetStreamFailed;
                strcpy(msg, "NetStream failed.");
            } else if (AVMATCH(&code, &av_NetStream_Play_Failed)) {
                err_code = RTMPErrorNetStreamPlayFailed;
                strcpy(msg, "NetStream play failed.");
            } else if (AVMATCH(&code, &av_NetStream_Play_StreamNotFound)) {
                err_code = RTMPErrorNetStreamPlayStreamNotFound;
                strcpy(msg, "NetStream play stream not found.");
            } else if (AVMATCH(&code, &av_NetConnection_Connect_InvalidApp)) {
                err_code = RTMPErrorNetConnectionConnectInvalidApp;
                strcpy(msg, "NetConnection connect invalip app.");
            } else {
                err_code = RTMPErrorUnknow;
                strcpy(msg, "Unknow error.");
            }

            RTMPError_Alloc(&error, strlen(msg));
            error.code = err_code;
            strcpy(error.message, msg);

            PILI_RTMP_Close(r, &error);

            RTMPError_Free(&error);

            RTMP_Log(RTMP_LOGERROR, "Closing connection: %s", code.av_val);
        }

        else if (AVMATCH(&code, &av_NetStream_Play_Start)) {
            int i;
            r->m_bPlaying = TRUE;
            for (i = 0; i < r->m_numCalls; i++) {
                if (AVMATCH(&r->m_methodCalls[i].name, &av_play)) {
                    AV_erase(r->m_methodCalls, &r->m_numCalls, i, TRUE);
                    break;
                }
            }
        }

        else if (AVMATCH(&code, &av_NetStream_Publish_Start)) {
            int i;
            r->m_bPlaying = TRUE;
            for (i = 0; i < r->m_numCalls; i++) {
                if (AVMATCH(&r->m_methodCalls[i].name, &av_publish)) {
                    AV_erase(r->m_methodCalls, &r->m_numCalls, i, TRUE);
                    break;
                }
            }
        }

        /* Return 1 if this is a Play.Complete or Play.Stop */
        else if (AVMATCH(&code, &av_NetStream_Play_Complete) || AVMATCH(&code, &av_NetStream_Play_Stop) || AVMATCH(&code, &av_NetStream_Play_UnpublishNotify)) {
            PILI_RTMP_Close(r, NULL);
            ret = 1;
        }

        else if (AVMATCH(&code, &av_NetStream_Seek_Notify)) {
            r->m_read.flags &= ~RTMP_READ_SEEKING;
        }

        else if (AVMATCH(&code, &av_NetStream_Pause_Notify)) {
            if (r->m_pausing == 1 || r->m_pausing == 2) {
                PILI_RTMP_SendPause(r, FALSE, r->m_pauseStamp, &error);
                r->m_pausing = 3;
            }
        }
    } else if (AVMATCH(&method, &av_playlist_ready)) {
        int i;
        for (i = 0; i < r->m_numCalls; i++) {
            if (AVMATCH(&r->m_methodCalls[i].name, &av_set_playlist)) {
                AV_erase(r->m_methodCalls, &r->m_numCalls, i, TRUE);
                break;
            }
        }
    } else {
    }
leave:
    AMF_Reset(&obj);
    return ret;
}

int PILI_RTMP_FindFirstMatchingProperty(AMFObject *obj, const AVal *name,
                                        AMFObjectProperty *p) {
    int n;
    /* this is a small object search to locate the "duration" property */
    for (n = 0; n < obj->o_num; n++) {
        AMFObjectProperty *prop = AMF_GetProp(obj, NULL, n);

        if (AVMATCH(&prop->p_name, name)) {
            *p = *prop;
            return TRUE;
        }

        if (prop->p_type == AMF_OBJECT) {
            if (PILI_RTMP_FindFirstMatchingProperty(&prop->p_vu.p_object, name, p))
                return TRUE;
        }
    }
    return FALSE;
}

/* Like above, but only check if name is a prefix of property */
int PILI_RTMP_FindPrefixProperty(AMFObject *obj, const AVal *name,
                                 AMFObjectProperty *p) {
    int n;
    for (n = 0; n < obj->o_num; n++) {
        AMFObjectProperty *prop = AMF_GetProp(obj, NULL, n);

        if (prop->p_name.av_len > name->av_len &&
            !memcmp(prop->p_name.av_val, name->av_val, name->av_len)) {
            *p = *prop;
            return TRUE;
        }

        if (prop->p_type == AMF_OBJECT) {
            if (PILI_RTMP_FindPrefixProperty(&prop->p_vu.p_object, name, p))
                return TRUE;
        }
    }
    return FALSE;
}

static int
    DumpMetaData(AMFObject *obj) {
    AMFObjectProperty *prop;
    int n;
    for (n = 0; n < obj->o_num; n++) {
        prop = AMF_GetProp(obj, NULL, n);
        if (prop->p_type != AMF_OBJECT) {
            char str[256] = "";
            switch (prop->p_type) {
                case AMF_NUMBER:
                    snprintf(str, 255, "%.2f", prop->p_vu.p_number);
                    break;
                case AMF_BOOLEAN:
                    snprintf(str, 255, "%s",
                             prop->p_vu.p_number != 0. ? "TRUE" : "FALSE");
                    break;
                case AMF_STRING:
                    snprintf(str, 255, "%.*s", prop->p_vu.p_aval.av_len,
                             prop->p_vu.p_aval.av_val);
                    break;
                case AMF_DATE:
                    snprintf(str, 255, "timestamp:%.2f", prop->p_vu.p_number);
                    break;
                default:
                    snprintf(str, 255, "INVALID TYPE 0x%02x",
                             (unsigned char)prop->p_type);
            }
            if (prop->p_name.av_len) {
                /* chomp */
                if (strlen(str) >= 1 && str[strlen(str) - 1] == '\n')
                    str[strlen(str) - 1] = '\0';
                RTMP_Log(RTMP_LOGINFO, "  %-22.*s%s", prop->p_name.av_len,
                         prop->p_name.av_val, str);
            }
        } else {
            if (prop->p_name.av_len)
                RTMP_Log(RTMP_LOGINFO, "%.*s:", prop->p_name.av_len, prop->p_name.av_val);
            DumpMetaData(&prop->p_vu.p_object);
        }
    }
    return FALSE;
}

SAVC(onMetaData);
SAVC(duration);
SAVC(video);
SAVC(audio);

static int
    HandleMetadata(PILI_RTMP *r, char *body, unsigned int len) {
    /* allright we get some info here, so parse it and print it */
    /* also keep duration or filesize to make a nice progress bar */

    AMFObject obj;
    AVal metastring;
    int ret = FALSE;

    int nRes = AMF_Decode(&obj, body, len, FALSE);
    if (nRes < 0) {
        RTMP_Log(RTMP_LOGERROR, "%s, error decoding meta data packet", __FUNCTION__);
        return FALSE;
    }

    AMF_Dump(&obj);
    AMFProp_GetString(AMF_GetProp(&obj, NULL, 0), &metastring);

    if (AVMATCH(&metastring, &av_onMetaData)) {
        AMFObjectProperty prop;
        /* Show metadata */
        RTMP_Log(RTMP_LOGINFO, "Metadata:");
        DumpMetaData(&obj);
        if (PILI_RTMP_FindFirstMatchingProperty(&obj, &av_duration, &prop)) {
            r->m_fDuration = prop.p_vu.p_number;
            /*RTMP_Log(RTMP_LOGDEBUG, "Set duration: %.2f", m_fDuration); */
        }
        /* Search for audio or video tags */
        if (PILI_RTMP_FindPrefixProperty(&obj, &av_video, &prop))
            r->m_read.dataType |= 1;
        if (PILI_RTMP_FindPrefixProperty(&obj, &av_audio, &prop))
            r->m_read.dataType |= 4;
        ret = TRUE;
    }
    AMF_Reset(&obj);
    return ret;
}

static void
    HandleChangeChunkSize(PILI_RTMP *r, const PILI_RTMPPacket *packet) {
    if (packet->m_nBodySize >= 4) {
        r->m_inChunkSize = AMF_DecodeInt32(packet->m_body);
        RTMP_Log(RTMP_LOGDEBUG, "%s, received: chunk size change to %d", __FUNCTION__,
                 r->m_inChunkSize);
    }
}

static void
    HandleAudio(PILI_RTMP *r, const PILI_RTMPPacket *packet) {
}

static void
    HandleVideo(PILI_RTMP *r, const PILI_RTMPPacket *packet) {
}

static void
    HandleCtrl(PILI_RTMP *r, const PILI_RTMPPacket *packet) {
    short nType = -1;
    unsigned int tmp;
    if (packet->m_body && packet->m_nBodySize >= 2)
        nType = AMF_DecodeInt16(packet->m_body);
    RTMP_Log(RTMP_LOGDEBUG, "%s, received ctrl. type: %d, len: %d", __FUNCTION__, nType,
             packet->m_nBodySize);
    /*RTMP_LogHex(packet.m_body, packet.m_nBodySize); */

    if (packet->m_nBodySize >= 6) {
        switch (nType) {
            case 0:
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Stream Begin %d", __FUNCTION__, tmp);
                break;

            case 1:
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Stream EOF %d", __FUNCTION__, tmp);
                if (r->m_pausing == 1)
                    r->m_pausing = 2;
                break;

            case 2:
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Stream Dry %d", __FUNCTION__, tmp);
                break;

            case 4:
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Stream IsRecorded %d", __FUNCTION__, tmp);
                break;

            case 6: /* server ping. reply with pong. */
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Ping %d", __FUNCTION__, tmp);
                PILI_RTMP_SendCtrl(r, 0x07, tmp, 0, NULL);
                break;

            /* FMS 3.5 servers send the following two controls to let the client
	 * know when the server has sent a complete buffer. I.e., when the
	 * server has sent an amount of data equal to m_nBufferMS in duration.
	 * The server meters its output so that data arrives at the client
	 * in realtime and no faster.
	 *
	 * The rtmpdump program tries to set m_nBufferMS as large as
	 * possible, to force the server to send data as fast as possible.
	 * In practice, the server appears to cap this at about 1 hour's
	 * worth of data. After the server has sent a complete buffer, and
	 * sends this BufferEmpty message, it will wait until the play
	 * duration of that buffer has passed before sending a new buffer.
	 * The BufferReady message will be sent when the new buffer starts.
	 * (There is no BufferReady message for the very first buffer;
	 * presumably the Stream Begin message is sufficient for that
	 * purpose.)
	 *
	 * If the network speed is much faster than the data bitrate, then
	 * there may be long delays between the end of one buffer and the
	 * start of the next.
	 *
	 * Since usually the network allows data to be sent at
	 * faster than realtime, and rtmpdump wants to download the data
	 * as fast as possible, we use this RTMP_LF_BUFX hack: when we
	 * get the BufferEmpty message, we send a Pause followed by an
	 * Unpause. This causes the server to send the next buffer immediately
	 * instead of waiting for the full duration to elapse. (That's
	 * also the purpose of the ToggleStream function, which rtmpdump
	 * calls if we get a read timeout.)
	 *
	 * Media player apps don't need this hack since they are just
	 * going to play the data in realtime anyway. It also doesn't work
	 * for live streams since they obviously can only be sent in
	 * realtime. And it's all moot if the network speed is actually
	 * slower than the media bitrate.
	 */
            case 31:
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Stream BufferEmpty %d", __FUNCTION__, tmp);
                if (!(r->Link.lFlags & RTMP_LF_BUFX))
                    break;
                if (!r->m_pausing) {
                    r->m_pauseStamp = r->m_channelTimestamp[r->m_mediaChannel];
                    PILI_RTMP_SendPause(r, TRUE, r->m_pauseStamp, NULL);
                    r->m_pausing = 1;
                } else if (r->m_pausing == 2) {
                    PILI_RTMP_SendPause(r, FALSE, r->m_pauseStamp, NULL);
                    r->m_pausing = 3;
                }
                break;

            case 32:
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Stream BufferReady %d", __FUNCTION__, tmp);
                break;

            default:
                tmp = AMF_DecodeInt32(packet->m_body + 2);
                RTMP_Log(RTMP_LOGDEBUG, "%s, Stream xx %d", __FUNCTION__, tmp);
                break;
        }
    }

    if (nType == 0x1A) {
        RTMP_Log(RTMP_LOGDEBUG, "%s, SWFVerification ping received: ", __FUNCTION__);
#ifdef CRYPTO
        /*RTMP_LogHex(packet.m_body, packet.m_nBodySize); */

        /* respond with HMAC SHA256 of decompressed SWF, key is the 30byte player key, also the last 30 bytes of the server handshake are applied */
        if (r->Link.SWFSize) {
            PILI_RTMP_SendCtrl(r, 0x1B, 0, 0);
        } else {
            RTMP_Log(RTMP_LOGERROR,
                     "%s: Ignoring SWFVerification request, use --swfVfy!",
                     __FUNCTION__);
        }
#else
        RTMP_Log(RTMP_LOGERROR,
                 "%s: Ignoring SWFVerification request, no CRYPTO support!",
                 __FUNCTION__);
#endif
    }
}

static void
    HandleServerBW(PILI_RTMP *r, const PILI_RTMPPacket *packet) {
    r->m_nServerBW = AMF_DecodeInt32(packet->m_body);
    RTMP_Log(RTMP_LOGDEBUG, "%s: server BW = %d", __FUNCTION__, r->m_nServerBW);
}

static void
    HandleClientBW(PILI_RTMP *r, const PILI_RTMPPacket *packet) {
    r->m_nClientBW = AMF_DecodeInt32(packet->m_body);
    if (packet->m_nBodySize > 4)
        r->m_nClientBW2 = packet->m_body[4];
    else
        r->m_nClientBW2 = -1;
    RTMP_Log(RTMP_LOGDEBUG, "%s: client BW = %d %d", __FUNCTION__, r->m_nClientBW,
             r->m_nClientBW2);
}

static int
    DecodeInt32LE(const char *data) {
    unsigned char *c = (unsigned char *)data;
    unsigned int val;

    val = (c[3] << 24) | (c[2] << 16) | (c[1] << 8) | c[0];
    return val;
}

static int
    EncodeInt32LE(char *output, int nVal) {
    output[0] = nVal;
    nVal >>= 8;
    output[1] = nVal;
    nVal >>= 8;
    output[2] = nVal;
    nVal >>= 8;
    output[3] = nVal;
    return 4;
}

int PILI_RTMP_ReadPacket(PILI_RTMP *r, PILI_RTMPPacket *packet) {
    uint8_t hbuf[RTMP_MAX_HEADER_SIZE] = {0};
    char *header = (char *)hbuf;
    int nSize, hSize, nToRead, nChunk;
    int didAlloc = FALSE;

    RTMP_Log(RTMP_LOGDEBUG2, "%s: fd=%d", __FUNCTION__, r->m_sb.sb_socket);

    if (ReadN(r, (char *)hbuf, 1) == 0) {
        RTMP_Log(RTMP_LOGERROR, "%s, failed to read PILI_RTMP packet header", __FUNCTION__);
        return FALSE;
    }

    packet->m_headerType = (hbuf[0] & 0xc0) >> 6;
    packet->m_nChannel = (hbuf[0] & 0x3f);
    header++;
    if (packet->m_nChannel == 0) {
        if (ReadN(r, (char *)&hbuf[1], 1) != 1) {
            RTMP_Log(RTMP_LOGERROR, "%s, failed to read PILI_RTMP packet header 2nd byte",
                     __FUNCTION__);
            return FALSE;
        }
        packet->m_nChannel = hbuf[1];
        packet->m_nChannel += 64;
        header++;
    } else if (packet->m_nChannel == 1) {
        int tmp;
        if (ReadN(r, (char *)&hbuf[1], 2) != 2) {
            RTMP_Log(RTMP_LOGERROR, "%s, failed to read PILI_RTMP packet header 3nd byte",
                     __FUNCTION__);
            return FALSE;
        }
        tmp = (hbuf[2] << 8) + hbuf[1];
        packet->m_nChannel = tmp + 64;
        RTMP_Log(RTMP_LOGDEBUG, "%s, m_nChannel: %0x", __FUNCTION__, packet->m_nChannel);
        header += 2;
    }

    nSize = packetSize[packet->m_headerType];

    if (nSize == RTMP_LARGE_HEADER_SIZE) /* if we get a full header the timestamp is absolute */
        packet->m_hasAbsTimestamp = TRUE;

    else if (nSize < RTMP_LARGE_HEADER_SIZE) { /* using values from the last message of this channel */
        if (r->m_vecChannelsIn[packet->m_nChannel])
            memcpy(packet, r->m_vecChannelsIn[packet->m_nChannel],
                   sizeof(PILI_RTMPPacket));
    }

    nSize--;

    if (nSize > 0 && ReadN(r, header, nSize) != nSize) {
        RTMP_Log(RTMP_LOGERROR, "%s, failed to read PILI_RTMP packet header. type: %x",
                 __FUNCTION__, (unsigned int)hbuf[0]);
        return FALSE;
    }

    hSize = nSize + (header - (char *)hbuf);

    if (nSize >= 3) {
        packet->m_nTimeStamp = AMF_DecodeInt24(header);

        /*RTMP_Log(RTMP_LOGDEBUG, "%s, reading PILI_RTMP packet chunk on channel %x, headersz %i, timestamp %i, abs timestamp %i", __FUNCTION__, packet.m_nChannel, nSize, packet.m_nTimeStamp, packet.m_hasAbsTimestamp); */

        if (nSize >= 6) {
            packet->m_nBodySize = AMF_DecodeInt24(header + 3);
            packet->m_nBytesRead = 0;
            PILI_RTMPPacket_Free(packet);

            if (nSize > 6) {
                packet->m_packetType = header[6];

                if (nSize == 11)
                    packet->m_nInfoField2 = DecodeInt32LE(header + 7);
            }
        }
        if (packet->m_nTimeStamp == 0xffffff) {
            if (ReadN(r, header + nSize, 4) != 4) {
                RTMP_Log(RTMP_LOGERROR, "%s, failed to read extended timestamp",
                         __FUNCTION__);
                return FALSE;
            }
            packet->m_nTimeStamp = AMF_DecodeInt32(header + nSize);
            hSize += 4;
        }
    }

    RTMP_LogHexString(RTMP_LOGDEBUG2, (uint8_t *)hbuf, hSize);

    if (packet->m_nBodySize > 0 && packet->m_body == NULL) {
        if (!PILI_RTMPPacket_Alloc(packet, packet->m_nBodySize)) {
            RTMP_Log(RTMP_LOGDEBUG, "%s, failed to allocate packet", __FUNCTION__);
            return FALSE;
        }
        didAlloc = TRUE;
        packet->m_headerType = (hbuf[0] & 0xc0) >> 6;
    }

    nToRead = packet->m_nBodySize - packet->m_nBytesRead;
    nChunk = r->m_inChunkSize;
    if (nToRead < nChunk)
        nChunk = nToRead;

    /* Does the caller want the raw chunk? */
    if (packet->m_chunk) {
        packet->m_chunk->c_headerSize = hSize;
        memcpy(packet->m_chunk->c_header, hbuf, hSize);
        packet->m_chunk->c_chunk = packet->m_body + packet->m_nBytesRead;
        packet->m_chunk->c_chunkSize = nChunk;
    }

    if (ReadN(r, packet->m_body + packet->m_nBytesRead, nChunk) != nChunk) {
        RTMP_Log(RTMP_LOGERROR, "%s, failed to read PILI_RTMP packet body. len: %lu",
                 __FUNCTION__, packet->m_nBodySize);
        return FALSE;
    }

    RTMP_LogHexString(RTMP_LOGDEBUG2, (uint8_t *)packet->m_body + packet->m_nBytesRead, nChunk);

    packet->m_nBytesRead += nChunk;

    /* keep the packet as ref for other packets on this channel */
    if (!r->m_vecChannelsIn[packet->m_nChannel])
        r->m_vecChannelsIn[packet->m_nChannel] = malloc(sizeof(PILI_RTMPPacket));
    memcpy(r->m_vecChannelsIn[packet->m_nChannel], packet, sizeof(PILI_RTMPPacket));

    if (RTMPPacket_IsReady(packet)) {
        /* make packet's timestamp absolute */
        if (!packet->m_hasAbsTimestamp)
            packet->m_nTimeStamp += r->m_channelTimestamp[packet->m_nChannel]; /* timestamps seem to be always relative!! */

        r->m_channelTimestamp[packet->m_nChannel] = packet->m_nTimeStamp;

        /* reset the data from the stored packet. we keep the header since we may use it later if a new packet for this channel */
        /* arrives and requests to re-use some info (small packet header) */
        r->m_vecChannelsIn[packet->m_nChannel]->m_body = NULL;
        r->m_vecChannelsIn[packet->m_nChannel]->m_nBytesRead = 0;
        r->m_vecChannelsIn[packet->m_nChannel]->m_hasAbsTimestamp = FALSE; /* can only be false if we reuse header */
    } else {
        packet->m_body = NULL; /* so it won't be erased on free */
    }

    return TRUE;
}

#ifndef CRYPTO
static int
    HandShake(PILI_RTMP *r, int FP9HandShake, RTMPError *error) {
    int i;
    uint32_t uptime, suptime;
    int bMatch;
    char type;
    char clientbuf[RTMP_SIG_SIZE + 1], *clientsig = clientbuf + 1;
    char serversig[RTMP_SIG_SIZE];

    clientbuf[0] = 0x03; /* not encrypted */

    uptime = htonl(PILI_RTMP_GetTime());
    memcpy(clientsig, &uptime, 4);

    memset(&clientsig[4], 0, 4);

#ifdef _DEBUG
    for (i = 8; i < RTMP_SIG_SIZE; i++)
        clientsig[i] = 0xff;
#else
    for (i = 8; i < RTMP_SIG_SIZE; i++)
        clientsig[i] = (char)(rand() % 256);
#endif

    if (!WriteN(r, clientbuf, RTMP_SIG_SIZE + 1, error))
        return FALSE;

    if (ReadN(r, &type, 1) != 1) /* 0x03 or 0x06 */
        return FALSE;

    RTMP_Log(RTMP_LOGDEBUG, "%s: Type Answer   : %02X", __FUNCTION__, type);

    if (type != clientbuf[0])
        RTMP_Log(RTMP_LOGWARNING, "%s: Type mismatch: client sent %d, server answered %d",
                 __FUNCTION__, clientbuf[0], type);

    if (ReadN(r, serversig, RTMP_SIG_SIZE) != RTMP_SIG_SIZE)
        return FALSE;

    /* decode server response */

    memcpy(&suptime, serversig, 4);
    suptime = ntohl(suptime);

    RTMP_Log(RTMP_LOGDEBUG, "%s: Server Uptime : %d", __FUNCTION__, suptime);
    RTMP_Log(RTMP_LOGDEBUG, "%s: FMS Version   : %d.%d.%d.%d", __FUNCTION__,
             serversig[4], serversig[5], serversig[6], serversig[7]);

    /* 2nd part of handshake */
    if (!WriteN(r, serversig, RTMP_SIG_SIZE, error))
        return FALSE;

    if (ReadN(r, serversig, RTMP_SIG_SIZE) != RTMP_SIG_SIZE)
        return FALSE;

    bMatch = (memcmp(serversig, clientsig, RTMP_SIG_SIZE) == 0);
    if (!bMatch) {
        RTMP_Log(RTMP_LOGWARNING, "%s, client signature does not match!", __FUNCTION__);
    }
    return TRUE;
}

static int
    SHandShake(PILI_RTMP *r, RTMPError *error) {
    int i;
    char serverbuf[RTMP_SIG_SIZE + 1], *serversig = serverbuf + 1;
    char clientsig[RTMP_SIG_SIZE];
    uint32_t uptime;
    int bMatch;

    if (ReadN(r, serverbuf, 1) != 1) /* 0x03 or 0x06 */
        return FALSE;

    RTMP_Log(RTMP_LOGDEBUG, "%s: Type Request  : %02X", __FUNCTION__, serverbuf[0]);

    if (serverbuf[0] != 3) {
        RTMP_Log(RTMP_LOGERROR, "%s: Type unknown: client sent %02X",
                 __FUNCTION__, serverbuf[0]);
        return FALSE;
    }

    uptime = htonl(PILI_RTMP_GetTime());
    memcpy(serversig, &uptime, 4);

    memset(&serversig[4], 0, 4);
#ifdef _DEBUG
    for (i = 8; i < RTMP_SIG_SIZE; i++)
        serversig[i] = 0xff;
#else
    for (i = 8; i < RTMP_SIG_SIZE; i++)
        serversig[i] = (char)(rand() % 256);
#endif

    if (!WriteN(r, serverbuf, RTMP_SIG_SIZE + 1, error))
        return FALSE;

    if (ReadN(r, clientsig, RTMP_SIG_SIZE) != RTMP_SIG_SIZE)
        return FALSE;

    /* decode client response */

    memcpy(&uptime, clientsig, 4);
    uptime = ntohl(uptime);

    RTMP_Log(RTMP_LOGDEBUG, "%s: Client Uptime : %d", __FUNCTION__, uptime);
    RTMP_Log(RTMP_LOGDEBUG, "%s: Player Version: %d.%d.%d.%d", __FUNCTION__,
             clientsig[4], clientsig[5], clientsig[6], clientsig[7]);

    /* 2nd part of handshake */
    if (!WriteN(r, clientsig, RTMP_SIG_SIZE, error))
        return FALSE;

    if (ReadN(r, clientsig, RTMP_SIG_SIZE) != RTMP_SIG_SIZE)
        return FALSE;

    bMatch = (memcmp(serversig, clientsig, RTMP_SIG_SIZE) == 0);
    if (!bMatch) {
        RTMP_Log(RTMP_LOGWARNING, "%s, client signature does not match!", __FUNCTION__);
    }
    return TRUE;
}
#endif

int PILI_RTMP_SendChunk(PILI_RTMP *r, PILI_RTMPChunk *chunk, RTMPError *error) {
    int wrote;
    char hbuf[RTMP_MAX_HEADER_SIZE];

    RTMP_Log(RTMP_LOGDEBUG2, "%s: fd=%d, size=%d", __FUNCTION__, r->m_sb.sb_socket,
             chunk->c_chunkSize);
    RTMP_LogHexString(RTMP_LOGDEBUG2, (uint8_t *)chunk->c_header, chunk->c_headerSize);
    if (chunk->c_chunkSize) {
        char *ptr = chunk->c_chunk - chunk->c_headerSize;
        RTMP_LogHexString(RTMP_LOGDEBUG2, (uint8_t *)chunk->c_chunk, chunk->c_chunkSize);
        /* save header bytes we're about to overwrite */
        memcpy(hbuf, ptr, chunk->c_headerSize);
        memcpy(ptr, chunk->c_header, chunk->c_headerSize);
        wrote = WriteN(r, ptr, chunk->c_headerSize + chunk->c_chunkSize, error);
        memcpy(ptr, hbuf, chunk->c_headerSize);
    } else
        wrote = WriteN(r, chunk->c_header, chunk->c_headerSize, error);
    return wrote;
}

int PILI_RTMP_SendPacket(PILI_RTMP *r, PILI_RTMPPacket *packet, int queue, RTMPError *error) {
    const PILI_RTMPPacket *prevPacket = r->m_vecChannelsOut[packet->m_nChannel];
    uint32_t last = 0;
    int nSize;
    int hSize, cSize;
    char *header, *hptr, *hend, hbuf[RTMP_MAX_HEADER_SIZE], c;
    uint32_t t;
    char *buffer, *tbuf = NULL, *toff = NULL;
    int nChunkSize;
    int tlen;

    if (prevPacket && packet->m_headerType != RTMP_PACKET_SIZE_LARGE) {
        /* compress a bit by using the prev packet's attributes */
        if (prevPacket->m_nBodySize == packet->m_nBodySize && prevPacket->m_packetType == packet->m_packetType && packet->m_headerType == RTMP_PACKET_SIZE_MEDIUM)
            packet->m_headerType = RTMP_PACKET_SIZE_SMALL;

        if (prevPacket->m_nTimeStamp == packet->m_nTimeStamp && packet->m_headerType == RTMP_PACKET_SIZE_SMALL)
            packet->m_headerType = RTMP_PACKET_SIZE_MINIMUM;
        last = prevPacket->m_nTimeStamp;
    }

    if (packet->m_headerType > 3) /* sanity */
    {
        if (error) {
            char *msg = "Sanity failed.";
            RTMPError_Alloc(error, strlen(msg));
            error->code = RTMPErrorSanityFailed;
            strcpy(error->message, msg);
        }

        RTMP_Log(RTMP_LOGERROR, "sanity failed!! trying to send header of type: 0x%02x.",
                 (unsigned char)packet->m_headerType);

        return FALSE;
    }

    nSize = packetSize[packet->m_headerType];
    hSize = nSize;
    cSize = 0;
    t = packet->m_nTimeStamp - last;

    if (packet->m_body) {
        header = packet->m_body - nSize;
        hend = packet->m_body;
    } else {
        header = hbuf + 6;
        hend = hbuf + sizeof(hbuf);
    }

    if (packet->m_nChannel > 319)
        cSize = 2;
    else if (packet->m_nChannel > 63)
        cSize = 1;
    if (cSize) {
        header -= cSize;
        hSize += cSize;
    }

    if (nSize > 1 && t >= 0xffffff) {
        header -= 4;
        hSize += 4;
    }

    hptr = header;
    c = packet->m_headerType << 6;
    switch (cSize) {
        case 0:
            c |= packet->m_nChannel;
            break;
        case 1:
            break;
        case 2:
            c |= 1;
            break;
    }
    *hptr++ = c;
    if (cSize) {
        int tmp = packet->m_nChannel - 64;
        *hptr++ = tmp & 0xff;
        if (cSize == 2)
            *hptr++ = tmp >> 8;
    }

    if (nSize > 1) {
        hptr = AMF_EncodeInt24(hptr, hend, t > 0xffffff ? 0xffffff : t);
    }

    if (nSize > 4) {
        hptr = AMF_EncodeInt24(hptr, hend, packet->m_nBodySize);
        *hptr++ = packet->m_packetType;
    }

    if (nSize > 8)
        hptr += EncodeInt32LE(hptr, packet->m_nInfoField2);

    if (nSize > 1 && t >= 0xffffff)
        hptr = AMF_EncodeInt32(hptr, hend, t);

    nSize = packet->m_nBodySize;
    buffer = packet->m_body;
    nChunkSize = r->m_outChunkSize;

    RTMP_Log(RTMP_LOGDEBUG2, "%s: fd=%d, size=%d", __FUNCTION__, r->m_sb.sb_socket,
             nSize);
    /* send all chunks in one HTTP request */
    if (r->Link.protocol & RTMP_FEATURE_HTTP) {
        int chunks = (nSize + nChunkSize - 1) / nChunkSize;
        if (chunks > 1) {
            tlen = chunks * (cSize + 1) + nSize + hSize;
            tbuf = malloc(tlen);
            if (!tbuf)
                return FALSE;
            toff = tbuf;
        }
    }
    while (nSize + hSize) {
        int wrote;

        if (nSize < nChunkSize)
            nChunkSize = nSize;

        RTMP_LogHexString(RTMP_LOGDEBUG2, (uint8_t *)header, hSize);
        RTMP_LogHexString(RTMP_LOGDEBUG2, (uint8_t *)buffer, nChunkSize);
        if (tbuf) {
            memcpy(toff, header, nChunkSize + hSize);
            toff += nChunkSize + hSize;
        } else {
            wrote = WriteN(r, header, nChunkSize + hSize, error);
            if (!wrote)
                return FALSE;
        }
        nSize -= nChunkSize;
        buffer += nChunkSize;
        hSize = 0;

        if (nSize > 0) {
            header = buffer - 1;
            hSize = 1;
            if (cSize) {
                header -= cSize;
                hSize += cSize;
            }
            *header = (0xc0 | c);
            if (cSize) {
                int tmp = packet->m_nChannel - 64;
                header[1] = tmp & 0xff;
                if (cSize == 2)
                    header[2] = tmp >> 8;
            }
        }
    }
    if (tbuf) {
        int wrote = WriteN(r, tbuf, toff - tbuf, error);
        free(tbuf);
        tbuf = NULL;
        if (!wrote)
            return FALSE;
    }

    /* we invoked a remote method */
    if (packet->m_packetType == 0x14) {
        AVal method;
        char *ptr;
        ptr = packet->m_body + 1;
        AMF_DecodeString(ptr, &method);
        RTMP_Log(RTMP_LOGDEBUG, "Invoking %s", method.av_val);
        /* keep it in call queue till result arrives */
        if (queue) {
            int txn;
            ptr += 3 + method.av_len;
            txn = (int)AMF_DecodeNumber(ptr);
            AV_queue(&r->m_methodCalls, &r->m_numCalls, &method, txn);
        }
    }

    if (!r->m_vecChannelsOut[packet->m_nChannel])
        r->m_vecChannelsOut[packet->m_nChannel] = malloc(sizeof(PILI_RTMPPacket));
    memcpy(r->m_vecChannelsOut[packet->m_nChannel], packet, sizeof(PILI_RTMPPacket));
    return TRUE;
}

int PILI_RTMP_Serve(PILI_RTMP *r, RTMPError *error) {
    return SHandShake(r, error);
}

void PILI_RTMP_Close(PILI_RTMP *r, RTMPError *error) {
    if (r->m_is_closing) {
        return;
    }
    r->m_is_closing = 1;
    int i;
    if (PILI_RTMP_IsConnected(r)) {
        if (r->m_stream_id > 0) {
            if ((r->Link.protocol & RTMP_FEATURE_WRITE))
                SendFCUnpublish(r, NULL);
            i = r->m_stream_id;
            r->m_stream_id = 0;
            SendDeleteStream(r, i, NULL);
        }
        if (r->m_clientID.av_val) {
            HTTP_Post(r, RTMPT_CLOSE, "", 1);
            free(r->m_clientID.av_val);
            r->m_clientID.av_val = NULL;
            r->m_clientID.av_len = 0;
        }
        PILI_RTMPSockBuf_Close(&r->m_sb);

        if (error && r->m_errorCallback) {
            r->m_errorCallback(error, r->m_userData);
        }
    }

    r->m_stream_id = -1;
    r->m_sb.sb_socket = -1;
    r->m_nBWCheckCounter = 0;
    r->m_nBytesIn = 0;
    r->m_nBytesInSent = 0;

    if (r->m_read.flags & RTMP_READ_HEADER) {
        free(r->m_read.buf);
        r->m_read.buf = NULL;
    }
    r->m_read.dataType = 0;
    r->m_read.flags = 0;
    r->m_read.status = 0;
    r->m_read.nResumeTS = 0;
    r->m_read.nIgnoredFrameCounter = 0;
    r->m_read.nIgnoredFlvFrameCounter = 0;

    r->m_write.m_nBytesRead = 0;
    PILI_RTMPPacket_Free(&r->m_write);

    for (i = 0; i < RTMP_CHANNELS; i++) {
        if (r->m_vecChannelsIn[i]) {
            PILI_RTMPPacket_Free(r->m_vecChannelsIn[i]);
            free(r->m_vecChannelsIn[i]);
            r->m_vecChannelsIn[i] = NULL;
        }
        if (r->m_vecChannelsOut[i]) {
            free(r->m_vecChannelsOut[i]);
            r->m_vecChannelsOut[i] = NULL;
        }
    }
    AV_clear(r->m_methodCalls, r->m_numCalls);
    r->m_methodCalls = NULL;
    r->m_numCalls = 0;
    r->m_numInvokes = 0;

    r->m_bPlaying = FALSE;
    r->m_sb.sb_size = 0;

    r->m_msgCounter = 0;
    r->m_resplen = 0;
    r->m_unackd = 0;

    free(r->Link.playpath0.av_val);
    r->Link.playpath0.av_val = NULL;

    if (r->Link.lFlags & RTMP_LF_FTCU) {
        free(r->Link.tcUrl.av_val);
        r->Link.tcUrl.av_val = NULL;
        r->Link.lFlags ^= RTMP_LF_FTCU;
    }

#ifdef CRYPTO
    if (r->Link.dh) {
        MDH_free(r->Link.dh);
        r->Link.dh = NULL;
    }
    if (r->Link.rc4keyIn) {
        RC4_free(r->Link.rc4keyIn);
        r->Link.rc4keyIn = NULL;
    }
    if (r->Link.rc4keyOut) {
        RC4_free(r->Link.rc4keyOut);
        r->Link.rc4keyOut = NULL;
    }
#endif
}

int PILI_RTMPSockBuf_Fill(PILI_RTMPSockBuf *sb) {
    int nBytes;

    if (!sb->sb_size)
        sb->sb_start = sb->sb_buf;

    while (1) {
        nBytes = sizeof(sb->sb_buf) - sb->sb_size - (sb->sb_start - sb->sb_buf);
#if defined(CRYPTO) && !defined(NO_SSL)
        if (sb->sb_ssl) {
            nBytes = TLS_read(sb->sb_ssl, sb->sb_start + sb->sb_size, nBytes);
        } else
#endif
        {
            nBytes = recv(sb->sb_socket, sb->sb_start + sb->sb_size, nBytes, 0);
        }
        if (nBytes != -1) {
            sb->sb_size += nBytes;
        } else {
            int sockerr = GetSockError();
            RTMP_Log(RTMP_LOGDEBUG, "%s, recv returned %d. GetSockError(): %d (%s)",
                     __FUNCTION__, nBytes, sockerr, strerror(sockerr));
            if (sockerr == EINTR && !PILI_RTMP_ctrlC)
                continue;

            if (sockerr == EWOULDBLOCK || sockerr == EAGAIN) {
                sb->sb_timedout = TRUE;
                nBytes = 0;
            }
        }
        break;
    }

    return nBytes;
}

int PILI_RTMPSockBuf_Send(PILI_RTMPSockBuf *sb, const char *buf, int len) {
    int rc;

#ifdef _DEBUG
    fwrite(buf, 1, len, netstackdump);
#endif

#if defined(CRYPTO) && !defined(NO_SSL)
    if (sb->sb_ssl) {
        rc = TLS_write(sb->sb_ssl, buf, len);
    } else
#endif
    {
        rc = send(sb->sb_socket, buf, len, 0);
    }
    return rc;
}

int PILI_RTMPSockBuf_Close(PILI_RTMPSockBuf *sb) {
#if defined(CRYPTO) && !defined(NO_SSL)
    if (sb->sb_ssl) {
        TLS_shutdown(sb->sb_ssl);
        TLS_close(sb->sb_ssl);
        sb->sb_ssl = NULL;
    }
#endif
    return closesocket(sb->sb_socket);
}

#define HEX2BIN(a) (((a)&0x40) ? ((a)&0xf) + 9 : ((a)&0xf))

static void
    DecodeTEA(AVal *key, AVal *text) {
    uint32_t *v, k[4] = {0}, u;
    uint32_t z, y, sum = 0, e, DELTA = 0x9e3779b9;
    int32_t p, q;
    int i, n;
    unsigned char *ptr, *out;

    /* prep key: pack 1st 16 chars into 4 LittleEndian ints */
    ptr = (unsigned char *)key->av_val;
    u = 0;
    n = 0;
    v = k;
    p = key->av_len > 16 ? 16 : key->av_len;
    for (i = 0; i < p; i++) {
        u |= ptr[i] << (n * 8);
        if (n == 3) {
            *v++ = u;
            u = 0;
            n = 0;
        } else {
            n++;
        }
    }
    /* any trailing chars */
    if (u)
        *v = u;

    /* prep text: hex2bin, multiples of 4 */
    n = (text->av_len + 7) / 8;
    out = malloc(n * 8);
    ptr = (unsigned char *)text->av_val;
    v = (uint32_t *)out;
    for (i = 0; i < n; i++) {
        u = (HEX2BIN(ptr[0]) << 4) + HEX2BIN(ptr[1]);
        u |= ((HEX2BIN(ptr[2]) << 4) + HEX2BIN(ptr[3])) << 8;
        u |= ((HEX2BIN(ptr[4]) << 4) + HEX2BIN(ptr[5])) << 16;
        u |= ((HEX2BIN(ptr[6]) << 4) + HEX2BIN(ptr[7])) << 24;
        *v++ = u;
        ptr += 8;
    }
    v = (uint32_t *)out;

/* http://www.movable-type.co.uk/scripts/tea-block.html */
#define MX (((z >> 5) ^ (y << 2)) + ((y >> 3) ^ (z << 4))) ^ ((sum ^ y) + (k[(p & 3) ^ e] ^ z));
    z = v[n - 1];
    y = v[0];
    q = 6 + 52 / n;
    sum = q * DELTA;
    while (sum != 0) {
        e = sum >> 2 & 3;
        for (p = n - 1; p > 0; p--)
            z = v[p - 1], y = v[p] -= MX;
        z = v[n - 1];
        y = v[0] -= MX;
        sum -= DELTA;
    }

    text->av_len /= 2;
    memcpy(text->av_val, out, text->av_len);
    free(out);
}

static int
    HTTP_Post(PILI_RTMP *r, RTMPTCmd cmd, const char *buf, int len) {
    char hbuf[512];
    int hlen = snprintf(hbuf, sizeof(hbuf), "POST /%s%s/%d HTTP/1.1\r\n"
                                            "Host: %.*s:%d\r\n"
                                            "Accept: */*\r\n"
                                            "User-Agent: Shockwave Flash\n"
                                            "Connection: Keep-Alive\n"
                                            "Cache-Control: no-cache\r\n"
                                            "Content-type: application/x-fcs\r\n"
                                            "Content-length: %d\r\n\r\n",
                        RTMPT_cmds[cmd],
                        r->m_clientID.av_val ? r->m_clientID.av_val : "",
                        r->m_msgCounter, r->Link.hostname.av_len, r->Link.hostname.av_val,
                        r->Link.port, len);
    PILI_RTMPSockBuf_Send(&r->m_sb, hbuf, hlen);
    hlen = PILI_RTMPSockBuf_Send(&r->m_sb, buf, len);
    r->m_msgCounter++;
    r->m_unackd++;
    return hlen;
}

static int
    HTTP_read(PILI_RTMP *r, int fill) {
    char *ptr;
    int hlen;

    if (fill)
        PILI_RTMPSockBuf_Fill(&r->m_sb);
    if (r->m_sb.sb_size < 144)
        return -1;
    if (strncmp(r->m_sb.sb_start, "HTTP/1.1 200 ", 13))
        return -1;
    ptr = strstr(r->m_sb.sb_start, "Content-Length:");
    if (!ptr)
        return -1;
    hlen = atoi(ptr + 16);
    ptr = strstr(ptr, "\r\n\r\n");
    if (!ptr)
        return -1;
    ptr += 4;
    r->m_sb.sb_size -= ptr - r->m_sb.sb_start;
    r->m_sb.sb_start = ptr;
    r->m_unackd--;

    if (!r->m_clientID.av_val) {
        r->m_clientID.av_len = hlen;
        r->m_clientID.av_val = malloc(hlen + 1);
        if (!r->m_clientID.av_val)
            return -1;
        r->m_clientID.av_val[0] = '/';
        memcpy(r->m_clientID.av_val + 1, ptr, hlen - 1);
        r->m_clientID.av_val[hlen] = 0;
        r->m_sb.sb_size = 0;
    } else {
        r->m_polling = *ptr++;
        r->m_resplen = hlen - 1;
        r->m_sb.sb_start++;
        r->m_sb.sb_size--;
    }
    return 0;
}

#define MAX_IGNORED_FRAMES 50

/* Read from the stream until we get a media packet.
 * Returns -3 if Play.Close/Stop, -2 if fatal error, -1 if no more media
 * packets, 0 if ignorable error, >0 if there is a media packet
 */
static int
    Read_1_Packet(PILI_RTMP *r, char *buf, unsigned int buflen) {
    uint32_t prevTagSize = 0;
    int rtnGetNextMediaPacket = 0, ret = RTMP_READ_EOF;
    PILI_RTMPPacket packet = {0};
    int recopy = FALSE;
    unsigned int size;
    char *ptr, *pend;
    uint32_t nTimeStamp = 0;
    unsigned int len;

    rtnGetNextMediaPacket = PILI_RTMP_GetNextMediaPacket(r, &packet);
    while (rtnGetNextMediaPacket) {
        char *packetBody = packet.m_body;
        unsigned int nPacketLen = packet.m_nBodySize;

        /* Return -3 if this was completed nicely with invoke message
       * Play.Stop or Play.Complete
       */
        if (rtnGetNextMediaPacket == 2) {
            RTMP_Log(RTMP_LOGDEBUG,
                     "Got Play.Complete or Play.Stop from server. "
                     "Assuming stream is complete");
            ret = RTMP_READ_COMPLETE;
            break;
        }

        r->m_read.dataType |= (((packet.m_packetType == 0x08) << 2) |
                               (packet.m_packetType == 0x09));

        if (packet.m_packetType == 0x09 && nPacketLen <= 5) {
            RTMP_Log(RTMP_LOGDEBUG, "ignoring too small video packet: size: %d",
                     nPacketLen);
            ret = RTMP_READ_IGNORE;
            break;
        }
        if (packet.m_packetType == 0x08 && nPacketLen <= 1) {
            RTMP_Log(RTMP_LOGDEBUG, "ignoring too small audio packet: size: %d",
                     nPacketLen);
            ret = RTMP_READ_IGNORE;
            break;
        }

        if (r->m_read.flags & RTMP_READ_SEEKING) {
            ret = RTMP_READ_IGNORE;
            break;
        }
#ifdef _DEBUG
        RTMP_Log(RTMP_LOGDEBUG, "type: %02X, size: %d, TS: %d ms, abs TS: %d",
                 packet.m_packetType, nPacketLen, packet.m_nTimeStamp,
                 packet.m_hasAbsTimestamp);
        if (packet.m_packetType == 0x09)
            RTMP_Log(RTMP_LOGDEBUG, "frametype: %02X", (*packetBody & 0xf0));
#endif

        if (r->m_read.flags & RTMP_READ_RESUME) {
            /* check the header if we get one */
            if (packet.m_nTimeStamp == 0) {
                if (r->m_read.nMetaHeaderSize > 0 && packet.m_packetType == 0x12) {
                    AMFObject metaObj;
                    int nRes =
                        AMF_Decode(&metaObj, packetBody, nPacketLen, FALSE);
                    if (nRes >= 0) {
                        AVal metastring;
                        AMFProp_GetString(AMF_GetProp(&metaObj, NULL, 0),
                                          &metastring);

                        if (AVMATCH(&metastring, &av_onMetaData)) {
                            /* compare */
                            if ((r->m_read.nMetaHeaderSize != nPacketLen) ||
                                (memcmp(r->m_read.metaHeader, packetBody,
                                        r->m_read.nMetaHeaderSize) != 0)) {
                                ret = RTMP_READ_ERROR;
                            }
                        }
                        AMF_Reset(&metaObj);
                        if (ret == RTMP_READ_ERROR)
                            break;
                    }
                }

                /* check first keyframe to make sure we got the right position
	       * in the stream! (the first non ignored frame)
	       */
                if (r->m_read.nInitialFrameSize > 0) {
                    /* video or audio data */
                    if (packet.m_packetType == r->m_read.initialFrameType && r->m_read.nInitialFrameSize == nPacketLen) {
                        /* we don't compare the sizes since the packet can
		       * contain several FLV packets, just make sure the
		       * first frame is our keyframe (which we are going
		       * to rewrite)
		       */
                        if (memcmp(r->m_read.initialFrame, packetBody,
                                   r->m_read.nInitialFrameSize) == 0) {
                            RTMP_Log(RTMP_LOGDEBUG, "Checked keyframe successfully!");
                            r->m_read.flags |= RTMP_READ_GOTKF;
                            /* ignore it! (what about audio data after it? it is
			   * handled by ignoring all 0ms frames, see below)
			   */
                            ret = RTMP_READ_IGNORE;
                            break;
                        }
                    }

                    /* hande FLV streams, even though the server resends the
		   * keyframe as an extra video packet it is also included
		   * in the first FLV stream chunk and we have to compare
		   * it and filter it out !!
		   */
                    if (packet.m_packetType == 0x16) {
                        /* basically we have to find the keyframe with the
		       * correct TS being nResumeTS
		       */
                        unsigned int pos = 0;
                        uint32_t ts = 0;

                        while (pos + 11 < nPacketLen) {
                            /* size without header (11) and prevTagSize (4) */
                            uint32_t dataSize =
                                AMF_DecodeInt24(packetBody + pos + 1);
                            ts = AMF_DecodeInt24(packetBody + pos + 4);
                            ts |= (packetBody[pos + 7] << 24);

#ifdef _DEBUG
                            RTMP_Log(RTMP_LOGDEBUG,
                                     "keyframe search: FLV Packet: type %02X, dataSize: %d, timeStamp: %d ms",
                                     packetBody[pos], dataSize, ts);
#endif
                            /* ok, is it a keyframe?:
			   * well doesn't work for audio!
			   */
                            if (packetBody[pos /*6928, test 0 */] ==
                                r->m_read.initialFrameType
                                /* && (packetBody[11]&0xf0) == 0x10 */) {
                                if (ts == r->m_read.nResumeTS) {
                                    RTMP_Log(RTMP_LOGDEBUG,
                                             "Found keyframe with resume-keyframe timestamp!");
                                    if (r->m_read.nInitialFrameSize != dataSize || memcmp(r->m_read.initialFrame, packetBody + pos + 11, r->m_read.nInitialFrameSize) != 0) {
                                        RTMP_Log(RTMP_LOGERROR,
                                                 "FLV Stream: Keyframe doesn't match!");
                                        ret = RTMP_READ_ERROR;
                                        break;
                                    }
                                    r->m_read.flags |= RTMP_READ_GOTFLVK;

                                    /* skip this packet?
				   * check whether skippable:
				   */
                                    if (pos + 11 + dataSize + 4 > nPacketLen) {
                                        RTMP_Log(RTMP_LOGWARNING,
                                                 "Non skipable packet since it doesn't end with chunk, stream corrupt!");
                                        ret = RTMP_READ_ERROR;
                                        break;
                                    }
                                    packetBody += (pos + 11 + dataSize + 4);
                                    nPacketLen -= (pos + 11 + dataSize + 4);

                                    goto stopKeyframeSearch;

                                } else if (r->m_read.nResumeTS < ts) {
                                    /* the timestamp ts will only increase with
				   * further packets, wait for seek
				   */
                                    goto stopKeyframeSearch;
                                }
                            }
                            pos += (11 + dataSize + 4);
                        }
                        if (ts < r->m_read.nResumeTS) {
                            RTMP_Log(RTMP_LOGERROR,
                                     "First packet does not contain keyframe, all "
                                     "timestamps are smaller than the keyframe "
                                     "timestamp; probably the resume seek failed?");
                        }
                    stopKeyframeSearch:;
                        if (!(r->m_read.flags & RTMP_READ_GOTFLVK)) {
                            RTMP_Log(RTMP_LOGERROR,
                                     "Couldn't find the seeked keyframe in this chunk!");
                            ret = RTMP_READ_IGNORE;
                            break;
                        }
                    }
                }
            }

            if (packet.m_nTimeStamp > 0 && (r->m_read.flags & (RTMP_READ_GOTKF | RTMP_READ_GOTFLVK))) {
                /* another problem is that the server can actually change from
	       * 09/08 video/audio packets to an FLV stream or vice versa and
	       * our keyframe check will prevent us from going along with the
	       * new stream if we resumed.
	       *
	       * in this case set the 'found keyframe' variables to true.
	       * We assume that if we found one keyframe somewhere and were
	       * already beyond TS > 0 we have written data to the output
	       * which means we can accept all forthcoming data including the
	       * change between 08/09 <-> FLV packets
	       */
                r->m_read.flags |= (RTMP_READ_GOTKF | RTMP_READ_GOTFLVK);
            }

            /* skip till we find our keyframe
	   * (seeking might put us somewhere before it)
	   */
            if (!(r->m_read.flags & RTMP_READ_GOTKF) &&
                packet.m_packetType != 0x16) {
                RTMP_Log(RTMP_LOGWARNING,
                         "Stream does not start with requested frame, ignoring data... ");
                r->m_read.nIgnoredFrameCounter++;
                if (r->m_read.nIgnoredFrameCounter > MAX_IGNORED_FRAMES)
                    ret = RTMP_READ_ERROR; /* fatal error, couldn't continue stream */
                else
                    ret = RTMP_READ_IGNORE;
                break;
            }
            /* ok, do the same for FLV streams */
            if (!(r->m_read.flags & RTMP_READ_GOTFLVK) &&
                packet.m_packetType == 0x16) {
                RTMP_Log(RTMP_LOGWARNING,
                         "Stream does not start with requested FLV frame, ignoring data... ");
                r->m_read.nIgnoredFlvFrameCounter++;
                if (r->m_read.nIgnoredFlvFrameCounter > MAX_IGNORED_FRAMES)
                    ret = RTMP_READ_ERROR;
                else
                    ret = RTMP_READ_IGNORE;
                break;
            }

            /* we have to ignore the 0ms frames since these are the first
	   * keyframes; we've got these so don't mess around with multiple
	   * copies sent by the server to us! (if the keyframe is found at a
	   * later position there is only one copy and it will be ignored by
	   * the preceding if clause)
	   */
            if (!(r->m_read.flags & RTMP_READ_NO_IGNORE) &&
                packet.m_packetType != 0x16) { /* exclude type 0x16 (FLV) since it can
				 * contain several FLV packets */
                if (packet.m_nTimeStamp == 0) {
                    ret = RTMP_READ_IGNORE;
                    break;
                } else {
                    /* stop ignoring packets */
                    r->m_read.flags |= RTMP_READ_NO_IGNORE;
                }
            }
        }

        /* calculate packet size and allocate slop buffer if necessary */
        size = nPacketLen +
               ((packet.m_packetType == 0x08 || packet.m_packetType == 0x09 || packet.m_packetType == 0x12) ? 11 : 0) +
               (packet.m_packetType != 0x16 ? 4 : 0);

        if (size + 4 > buflen) {
            /* the extra 4 is for the case of an FLV stream without a last
	   * prevTagSize (we need extra 4 bytes to append it) */
            r->m_read.buf = malloc(size + 4);
            if (r->m_read.buf == 0) {
                RTMP_Log(RTMP_LOGERROR, "Couldn't allocate memory!");
                ret = RTMP_READ_ERROR; /* fatal error */
                break;
            }
            recopy = TRUE;
            ptr = r->m_read.buf;
        } else {
            ptr = buf;
        }
        pend = ptr + size + 4;

        /* use to return timestamp of last processed packet */

        /* audio (0x08), video (0x09) or metadata (0x12) packets :
       * construct 11 byte header then add PILI_RTMP packet's data */
        if (packet.m_packetType == 0x08 || packet.m_packetType == 0x09 || packet.m_packetType == 0x12) {
            nTimeStamp = r->m_read.nResumeTS + packet.m_nTimeStamp;
            prevTagSize = 11 + nPacketLen;

            *ptr = packet.m_packetType;
            ptr++;
            ptr = AMF_EncodeInt24(ptr, pend, nPacketLen);

#if 0
	    if(packet.m_packetType == 0x09) { /* video */

	     /* H264 fix: */
	     if((packetBody[0] & 0x0f) == 7) { /* CodecId = H264 */
	     uint8_t packetType = *(packetBody+1);

	     uint32_t ts = AMF_DecodeInt24(packetBody+2); /* composition time */
	     int32_t cts = (ts+0xff800000)^0xff800000;
	     RTMP_Log(RTMP_LOGDEBUG, "cts  : %d\n", cts);

	     nTimeStamp -= cts;
	     /* get rid of the composition time */
	     CRTMP::EncodeInt24(packetBody+2, 0);
	     }
	     RTMP_Log(RTMP_LOGDEBUG, "VIDEO: nTimeStamp: 0x%08X (%d)\n", nTimeStamp, nTimeStamp);
	     }
#endif

            ptr = AMF_EncodeInt24(ptr, pend, nTimeStamp);
            *ptr = (char)((nTimeStamp & 0xFF000000) >> 24);
            ptr++;

            /* stream id */
            ptr = AMF_EncodeInt24(ptr, pend, 0);
        }

        memcpy(ptr, packetBody, nPacketLen);
        len = nPacketLen;

        /* correct tagSize and obtain timestamp if we have an FLV stream */
        if (packet.m_packetType == 0x16) {
            unsigned int pos = 0;
            int delta;

            /* grab first timestamp and see if it needs fixing */
            nTimeStamp = AMF_DecodeInt24(packetBody + 4);
            nTimeStamp |= (packetBody[7] << 24);
            delta = packet.m_nTimeStamp - nTimeStamp;

            while (pos + 11 < nPacketLen) {
                /* size without header (11) and without prevTagSize (4) */
                uint32_t dataSize = AMF_DecodeInt24(packetBody + pos + 1);
                nTimeStamp = AMF_DecodeInt24(packetBody + pos + 4);
                nTimeStamp |= (packetBody[pos + 7] << 24);

                if (delta) {
                    nTimeStamp += delta;
                    AMF_EncodeInt24(ptr + pos + 4, pend, nTimeStamp);
                    ptr[pos + 7] = nTimeStamp >> 24;
                }

                /* set data type */
                r->m_read.dataType |= (((*(packetBody + pos) == 0x08) << 2) |
                                       (*(packetBody + pos) == 0x09));

                if (pos + 11 + dataSize + 4 > nPacketLen) {
                    if (pos + 11 + dataSize > nPacketLen) {
                        RTMP_Log(RTMP_LOGERROR,
                                 "Wrong data size (%lu), stream corrupted, aborting!",
                                 dataSize);
                        ret = RTMP_READ_ERROR;
                        break;
                    }
                    RTMP_Log(RTMP_LOGWARNING, "No tagSize found, appending!");

                    /* we have to append a last tagSize! */
                    prevTagSize = dataSize + 11;
                    AMF_EncodeInt32(ptr + pos + 11 + dataSize, pend,
                                    prevTagSize);
                    size += 4;
                    len += 4;
                } else {
                    prevTagSize =
                        AMF_DecodeInt32(packetBody + pos + 11 + dataSize);

#ifdef _DEBUG
                    RTMP_Log(RTMP_LOGDEBUG,
                             "FLV Packet: type %02X, dataSize: %lu, tagSize: %lu, timeStamp: %lu ms",
                             (unsigned char)packetBody[pos], dataSize, prevTagSize,
                             nTimeStamp);
#endif

                    if (prevTagSize != (dataSize + 11)) {
#ifdef _DEBUG
                        RTMP_Log(RTMP_LOGWARNING,
                                 "Tag and data size are not consitent, writing tag size according to dataSize+11: %d",
                                 dataSize + 11);
#endif

                        prevTagSize = dataSize + 11;
                        AMF_EncodeInt32(ptr + pos + 11 + dataSize, pend,
                                        prevTagSize);
                    }
                }

                pos += prevTagSize + 4; /*(11+dataSize+4); */
            }
        }
        ptr += len;

        if (packet.m_packetType != 0x16) {
            /* FLV tag packets contain their own prevTagSize */
            AMF_EncodeInt32(ptr, pend, prevTagSize);
        }

        /* In non-live this nTimeStamp can contain an absolute TS.
       * Update ext timestamp with this absolute offset in non-live mode
       * otherwise report the relative one
       */
        /* RTMP_Log(RTMP_LOGDEBUG, "type: %02X, size: %d, pktTS: %dms, TS: %dms, bLiveStream: %d", packet.m_packetType, nPacketLen, packet.m_nTimeStamp, nTimeStamp, r->Link.lFlags & RTMP_LF_LIVE); */
        r->m_read.timestamp = (r->Link.lFlags & RTMP_LF_LIVE) ? packet.m_nTimeStamp : nTimeStamp;

        ret = size;
        break;
    }

    if (rtnGetNextMediaPacket)
        PILI_RTMPPacket_Free(&packet);

    if (recopy) {
        len = ret > buflen ? buflen : ret;
        memcpy(buf, r->m_read.buf, len);
        r->m_read.bufpos = r->m_read.buf + len;
        r->m_read.buflen = ret - len;
    }
    return ret;
}

static const char flvHeader[] = {'F', 'L', 'V', 0x01,
                                 0x00, /* 0x04 == audio, 0x01 == video */
                                 0x00, 0x00, 0x00, 0x09,
                                 0x00, 0x00, 0x00, 0x00};

#define HEADERBUF (128 * 1024)
int PILI_RTMP_Read(PILI_RTMP *r, char *buf, int size) {
    int nRead = 0, total = 0;

/* can't continue */
fail:
    switch (r->m_read.status) {
        case RTMP_READ_EOF:
        case RTMP_READ_COMPLETE:
            return 0;
        case RTMP_READ_ERROR: /* corrupted stream, resume failed */
            SetSockError(EINVAL);
            return -1;
        default:
            break;
    }

    if ((r->m_read.flags & RTMP_READ_SEEKING) && r->m_read.buf) {
        /* drop whatever's here */
        free(r->m_read.buf);
        r->m_read.buf = NULL;
        r->m_read.bufpos = NULL;
        r->m_read.buflen = 0;
    }

    /* If there's leftover data buffered, use it up */
    if (r->m_read.buf) {
        nRead = r->m_read.buflen;
        if (nRead > size)
            nRead = size;
        memcpy(buf, r->m_read.bufpos, nRead);
        r->m_read.buflen -= nRead;
        if (!r->m_read.buflen) {
            free(r->m_read.buf);
            r->m_read.buf = NULL;
            r->m_read.bufpos = NULL;
        } else {
            r->m_read.bufpos += nRead;
        }
        buf += nRead;
        total += nRead;
        size -= nRead;
    }

    while (size > 0 && (nRead = Read_1_Packet(r, buf, size)) >= 0) {
        if (!nRead) continue;
        buf += nRead;
        total += nRead;
        size -= nRead;
        break;
    }
    if (nRead < 0)
        r->m_read.status = nRead;

    if (size < 0)
        total += size;
    return total;
}

static const AVal av_setDataFrame = AVC("@setDataFrame");

int PILI_RTMP_Write(PILI_RTMP *r, const char *buf, int size, RTMPError *error) {
    PILI_RTMPPacket *pkt = &r->m_write;
    char *pend, *enc;
    int s2 = size, ret, num;

    pkt->m_nChannel = 0x04; /* source channel */
    pkt->m_nInfoField2 = r->m_stream_id;

    while (s2) {
        if (!pkt->m_nBytesRead) {
            if (size < 11) {
                /* FLV pkt too small */
                return 0;
            }

            if (buf[0] == 'F' && buf[1] == 'L' && buf[2] == 'V') {
                buf += 13;
                s2 -= 13;
            }

            pkt->m_packetType = *buf++;
            pkt->m_nBodySize = AMF_DecodeInt24(buf);
            buf += 3;
            pkt->m_nTimeStamp = AMF_DecodeInt24(buf);
            buf += 3;
            pkt->m_nTimeStamp |= *buf++ << 24;
            buf += 3;
            s2 -= 11;

            if (((pkt->m_packetType == 0x08 || pkt->m_packetType == 0x09) &&
                 !pkt->m_nTimeStamp) ||
                pkt->m_packetType == 0x12) {
                pkt->m_headerType = RTMP_PACKET_SIZE_LARGE;
                if (pkt->m_packetType == 0x12)
                    pkt->m_nBodySize += 16;
            } else {
                pkt->m_headerType = RTMP_PACKET_SIZE_MEDIUM;
            }

            if (!PILI_RTMPPacket_Alloc(pkt, pkt->m_nBodySize)) {
                RTMP_Log(RTMP_LOGDEBUG, "%s, failed to allocate packet", __FUNCTION__);
                return FALSE;
            }
            enc = pkt->m_body;
            pend = enc + pkt->m_nBodySize;
            if (pkt->m_packetType == 0x12) {
                enc = AMF_EncodeString(enc, pend, &av_setDataFrame);
                pkt->m_nBytesRead = enc - pkt->m_body;
            }
        } else {
            enc = pkt->m_body + pkt->m_nBytesRead;
        }
        num = pkt->m_nBodySize - pkt->m_nBytesRead;
        if (num > s2)
            num = s2;
        memcpy(enc, buf, num);
        pkt->m_nBytesRead += num;
        s2 -= num;
        buf += num;
        if (pkt->m_nBytesRead == pkt->m_nBodySize) {
            ret = PILI_RTMP_SendPacket(r, pkt, FALSE, error);
            PILI_RTMPPacket_Free(pkt);
            pkt->m_nBytesRead = 0;
            if (!ret)
                return -1;
            buf += 4;
            s2 -= 4;
            if (s2 < 0)
                break;
        }
    }
    return size + s2;
}
