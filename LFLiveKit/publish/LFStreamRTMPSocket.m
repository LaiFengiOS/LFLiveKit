//
//  LFStreamRTMPSocket.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFStreamRTMPSocket.h"
#import "LFStreamLog.h"

#if __has_include(<pili-librtmp/rtmp.h>)
#import <pili-librtmp/rtmp.h>
#else
#import "rtmp.h"
#import "log.h"
#endif

static const NSInteger RetryTimesBreaken = 5;  ///<  重连1分钟  3秒一次 一共20次
static const NSInteger RetryTimesMargin = 3;


#define RTMP_RECEIVE_TIMEOUT    2
#define DATA_ITEMS_MAX_COUNT 100
#define RTMP_DATA_RESERVE_SIZE 400
#define RTMP_HEAD_SIZE (sizeof(RTMPPacket) + RTMP_MAX_HEADER_SIZE)

#define SAVC(x)    static const AVal av_ ## x = AVC(#x)

static const AVal av_setDataFrame = AVC("@setDataFrame");
static const AVal av_SDKVersion = AVC("LFLiveKit 2.4.0");
SAVC(onMetaData);
SAVC(duration);
SAVC(width);
SAVC(height);
SAVC(videocodecid);
SAVC(videodatarate);
SAVC(framerate);
SAVC(audiocodecid);
SAVC(audiodatarate);
SAVC(audiosamplerate);
SAVC(audiosamplesize);
//SAVC(audiochannels);
SAVC(stereo);
SAVC(encoder);
//SAVC(av_stereo);
SAVC(fileSize);
SAVC(avc1);
SAVC(mp4a);

@interface LFStreamRTMPSocket ()<LFStreamingBufferDelegate>
{
    PILI_RTMP *_rtmp;
}
@property (nonatomic, weak) id<LFStreamSocketDelegate> delegate;
@property (nonatomic, strong) LFLiveStreamInfo *stream;
@property (nonatomic, strong) LFStreamingBuffer *buffer;
@property (nonatomic, strong) LFLiveDebug *debugInfo;
@property (nonatomic, strong) dispatch_queue_t rtmpSendQueue;
//错误信息
@property (nonatomic, assign) RTMPError error;
@property (nonatomic, assign) NSInteger retryTimes4netWorkBreaken;
@property (nonatomic, assign) NSInteger reconnectInterval;
@property (nonatomic, assign) NSInteger reconnectCount;

@property (atomic, assign) BOOL isSending;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isConnecting;
@property (nonatomic, assign) BOOL isReconnecting;

@property (nonatomic, assign) BOOL sendVideoHead;
@property (nonatomic, assign) BOOL sendAudioHead;

@property (strong, nonatomic) NSData *seiData;

@end

@implementation LFStreamRTMPSocket

static inline void set_rtmp_str(AVal *val, const char *str)
{
    bool valid  = (str && *str);
    val->av_val = valid ? (char*)str       : NULL;
    val->av_len = valid ? (int)strlen(str) : 0;
}

#pragma mark -- LFStreamSocket
- (nullable instancetype)initWithStream:(nullable LFLiveStreamInfo *)stream{
    return [self initWithStream:stream reconnectInterval:0 reconnectCount:0];
}

- (nullable instancetype)initWithStream:(nullable LFLiveStreamInfo *)stream reconnectInterval:(NSInteger)reconnectInterval reconnectCount:(NSInteger)reconnectCount{
    if (!stream) @throw [NSException exceptionWithName:@"LFStreamRtmpSocket init error" reason:@"stream is nil" userInfo:nil];
    if (self = [super init]) {
        _stream = stream;
        if (reconnectInterval > 0) _reconnectInterval = reconnectInterval;
        else _reconnectInterval = RetryTimesMargin;
        
        if (reconnectCount > 0) _reconnectCount = reconnectCount;
        else _reconnectCount = RetryTimesBreaken;
        
        [self addObserver:self forKeyPath:@"isSending" options:NSKeyValueObservingOptionNew context:nil];//这里改成observer主要考虑一直到发送出错情况下，可以继续发送

#if DEBUG
        RTMP_LogSetLevel(RTMP_LOGDEBUG);
#endif
    }
    return self;
}

- (void)dealloc{
    [self removeObserver:self forKeyPath:@"isSending"];
}

- (void)start {
    dispatch_async(self.rtmpSendQueue, ^{
        [self _start];
    });
}

- (void)_start {
    if (!_stream) return;
    if (_isConnecting) return;
    if (_rtmp != NULL) return;
    self.debugInfo.streamId = self.stream.streamId;
    self.debugInfo.uploadUrl = self.stream.url;
    self.debugInfo.isRtmp = YES;
    if (_isConnecting) return;
    
    _isConnecting = YES;
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:LFLivePending];
    }
    
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
    }
    [self RTMP264_Connect:_stream.url tcUrl:_stream.tcUrl];
}

- (void)stop {
    dispatch_async(self.rtmpSendQueue, ^{
        [self _stopWithStatus:LFLiveStop];
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    });
}

- (void)switched {
    dispatch_async(self.rtmpSendQueue, ^{
        [self _stopWithStatus:LFLiveSwitched];
        [NSObject cancelPreviousPerformRequestsWithTarget:self];
    });
}

- (void)_stopWithStatus:(LFLiveState)status {
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:status];
    }
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
        _rtmp = NULL;
    }
    [self clean];
}

- (void)sendFrame:(LFFrame *)frame {
    if (!frame) return;
    [self.buffer appendObject:frame];
    
    if(!self.isSending){
        [self sendFrame];
    }
}

- (void)setDelegate:(id<LFStreamSocketDelegate>)delegate {
    _delegate = delegate;
}

- (void)streamURLChanged:(NSString *)url {
    dispatch_async(self.rtmpSendQueue, ^{
        self.stream.url = url;
        self.debugInfo.streamId = self.stream.streamId;
        self.debugInfo.uploadUrl = self.stream.url;
        self.debugInfo.isRtmp = YES;

        [self clean];
        [self reconnect];
    });
}

#pragma mark -- CustomMethod

- (void)sendFrame {
    __weak typeof(self) _self = self;
    dispatch_async(self.rtmpSendQueue, ^{
        if (!_self.isSending && _self.buffer.list.count > 0) {
            _self.isSending = YES;
            
            if (!_self.isConnected || _self.isReconnecting || _self.isConnecting || !_rtmp){
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // 这里只为了不循环调用sendFrame方法 调用栈是保证先出栈再进栈
                    _self.isSending = NO;
                });
                return;
            }
            
            // 调用发送接口
            LFFrame *frame = [_self.buffer popFirstObject];
            if ([frame isKindOfClass:[LFVideoFrame class]]) {
                if (!_self.sendVideoHead || ((LFVideoFrame*)frame).formatChanged) {
                    _self.sendVideoHead = YES;
                    if(!((LFVideoFrame*)frame).sps || !((LFVideoFrame*)frame).pps){
                        _self.isSending = NO;
                        return;
                    }
                    [_self sendVideoHeader:(LFVideoFrame *)frame];
                } else {
                    [_self sendVideo:(LFVideoFrame *)frame];
                }
            } else {
                if (!_self.sendAudioHead) {
                    _self.sendAudioHead = YES;
                    if(!((LFAudioFrame*)frame).audioInfo){
                        _self.isSending = NO;
                        return;
                    }
                    [_self sendAudioHeader:(LFAudioFrame *)frame];
                } else {
                    [_self sendAudio:frame];
                }
            }
            
            //debug更新
            _self.debugInfo.totalFrame++;
            _self.debugInfo.dropFrame += _self.buffer.lastDropFrames;
            _self.buffer.lastDropFrames = 0;
            
            _self.debugInfo.dataFlow += frame.data.length;
            _self.debugInfo.elapsedMilli = CACurrentMediaTime() - _self.debugInfo.timeStamp;
            if (_self.debugInfo.elapsedMilli < 1) {
                _self.debugInfo.bandwidth += frame.data.length;
                if ([frame isKindOfClass:[LFAudioFrame class]]) {
                    _self.debugInfo.capturedAudioCount++;
                } else {
                    _self.debugInfo.capturedVideoCount++;
                }
                
                _self.debugInfo.unSendCount = _self.buffer.list.count;
            } else {
                _self.debugInfo.currentBandwidth = _self.debugInfo.bandwidth;
                _self.debugInfo.currentCapturedAudioCount = _self.debugInfo.capturedAudioCount;
                _self.debugInfo.currentCapturedVideoCount = _self.debugInfo.capturedVideoCount;
                if (_self.delegate && [_self.delegate respondsToSelector:@selector(socketDebug:debugInfo:)]) {
                    [_self.delegate socketDebug:_self debugInfo:_self.debugInfo];
                }
                _self.debugInfo.bandwidth = 0;
                _self.debugInfo.capturedAudioCount = 0;
                _self.debugInfo.capturedVideoCount = 0;
                _self.debugInfo.timeStamp = CACurrentMediaTime();
            }
            
            _self.debugInfo.elapsedMilliForSpeed = CACurrentMediaTime() - _self.debugInfo.timeStampForSpeed;
            _self.debugInfo.bandwidthForSpeed += frame.data.length;
            if(_self.debugInfo.elapsedMilliForSpeed >= 20){
                int speed = (int)_self.debugInfo.bandwidthForSpeed/20;
                if(_self.debugInfo.elapsedMilliForSpeed < 100){
                    //非第一次统计.才记录.
                    [[LFStreamLog logger] logWithDict:@{@"lt": @"pspd",
                                                        @"spd": @(speed)}];
                }
                _self.debugInfo.lastSpeed = _self.debugInfo.bandwidthForSpeed;
                _self.debugInfo.bandwidthForSpeed = 0;
                _self.debugInfo.timeStampForSpeed = CACurrentMediaTime();
            }
            
            //修改发送状态
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                // 这里只为了不循环调用sendFrame方法 调用栈是保证先出栈再进栈
                _self.isSending = NO;
            });
            
        }
    });
}

- (void)clean {
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _isConnected = NO;
    _sendAudioHead = NO;
    _sendVideoHead = NO;
    self.debugInfo = nil;
    [self.buffer removeAllObject];
    self.retryTimes4netWorkBreaken = 0;
}

- (NSInteger)RTMP264_Connect:(NSString *)url tcUrl:(NSString *)tcUrl {
    //由于摄像头的timestamp是一直在累加，需要每次得到相对时间戳
    //分配与初始化
    _rtmp = PILI_RTMP_Alloc();
    PILI_RTMP_Init(_rtmp);
    
    //设置URL
    const char * push_url = [url cStringUsingEncoding:NSASCIIStringEncoding];
    if (PILI_RTMP_SetupURL(_rtmp, push_url, &_error) == FALSE) {
        //log(LOG_ERR, "RTMP_SetupURL() failed!");
        goto Failed;
    }
    if (tcUrl != NULL) {
        const char * tc_url = [tcUrl cStringUsingEncoding:NSASCIIStringEncoding];
        set_rtmp_str(&_rtmp->Link.tcUrl, tc_url);
    }
    _rtmp->m_errorCallback = RTMPErrorCallback;
    _rtmp->m_connCallback = ConnectionTimeCallback;
    _rtmp->m_userData = (__bridge void *)self;
    _rtmp->m_msgCounter = 1;
    _rtmp->Link.timeout = RTMP_RECEIVE_TIMEOUT;
    
    //设置可写，即发布流，这个函数必须在连接前使用，否则无效
    PILI_RTMP_EnableWrite(_rtmp);
    
    //连接服务器
    if (PILI_RTMP_Connect(_rtmp, NULL, &_error) == FALSE) {
        goto Failed;
    }
    
    // logging
    [LFStreamLog logger].host = [NSString stringWithUTF8String:_rtmp->ipstr];
    [[LFStreamLog logger] fetchHostStatus];
    
    //连接流
    if (PILI_RTMP_ConnectStream(_rtmp, 0, &_error) == FALSE) {
        goto Failed;
    }
    int64_t initInterval = ([NSDate date].timeIntervalSince1970 - [LFStreamLog logger].initStartTime) * 1000;
    [[LFStreamLog logger] logWithDict:@{@"lt": @"pinit",
                                        @"interval": @(initInterval)}];
    //reconnect times
    [[LFStreamLog logger] logWithDict:@{@"lt": @"retryTimes",@"retryTimes": @(self.retryTimes4netWorkBreaken),
                                        @"maxTryTimes": @(self.reconnectCount)}];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:LFLiveStart];
    }
    
    [self sendMetaData];
    
    _isConnected = YES;
    _isConnecting = NO;
    _isReconnecting = NO;
    _isSending = NO;
    _retryTimes4netWorkBreaken = 0;
    return 0;
    
Failed:
    PILI_RTMP_Close(_rtmp, &_error);
    PILI_RTMP_Free(_rtmp);
    _rtmp = NULL;
    [self reconnect];
    return -1;
}

#pragma mark -- Rtmp Send

- (void)sendMetaData {
    PILI_RTMPPacket packet;
    
    char pbuf[2048], *pend = pbuf + sizeof(pbuf);
    
    packet.m_nChannel = 0x03;                   // control channel (invoke)
    packet.m_headerType = RTMP_PACKET_SIZE_LARGE;
    packet.m_packetType = RTMP_PACKET_TYPE_INFO;
    packet.m_nTimeStamp = 0;
    packet.m_nInfoField2 = _rtmp->m_stream_id;
    packet.m_hasAbsTimestamp = TRUE;
    packet.m_body = pbuf + RTMP_MAX_HEADER_SIZE;
    
    char *enc = packet.m_body;
    enc = AMF_EncodeString(enc, pend, &av_setDataFrame);
    enc = AMF_EncodeString(enc, pend, &av_onMetaData);
    
    *enc++ = AMF_OBJECT;
    
    enc = AMF_EncodeNamedNumber(enc, pend, &av_duration, 0.0);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_fileSize, 0.0);
    
    // videosize
    enc = AMF_EncodeNamedNumber(enc, pend, &av_width, _stream.videoConfiguration.videoSize.width);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_height, _stream.videoConfiguration.videoSize.height);
    
    // video
    enc = AMF_EncodeNamedString(enc, pend, &av_videocodecid, &av_avc1);
    
    enc = AMF_EncodeNamedNumber(enc, pend, &av_videodatarate, _stream.videoConfiguration.videoBitRate / 1000.f);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_framerate, _stream.videoConfiguration.videoFrameRate);
    
    // audio
    enc = AMF_EncodeNamedString(enc, pend, &av_audiocodecid, &av_mp4a);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiodatarate, _stream.audioConfiguration.audioBitrate);
    
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplerate, _stream.audioConfiguration.audioSampleRate);
    enc = AMF_EncodeNamedNumber(enc, pend, &av_audiosamplesize, 16.0);
    enc = AMF_EncodeNamedBoolean(enc, pend, &av_stereo, _stream.audioConfiguration.numberOfChannels == 2);
    
    // sdk version
    enc = AMF_EncodeNamedString(enc, pend, &av_encoder, &av_SDKVersion);
    
    *enc++ = 0;
    *enc++ = 0;
    *enc++ = AMF_OBJECT_END;
    
    packet.m_nBodySize = (uint32_t)(enc - packet.m_body);
    if (!PILI_RTMP_SendPacket(_rtmp, &packet, FALSE, &_error)) {
        return;
    }
}

- (void)sendVideoHeader:(LFVideoFrame *)videoFrame {
    
    unsigned char *body = NULL;
    NSInteger iIndex = 0;
    NSInteger rtmpLength = 1024;
    const char *sps = videoFrame.sps.bytes;
    const char *pps = videoFrame.pps.bytes;
    NSInteger spsLen = videoFrame.sps.length;
    NSInteger ppsLen = videoFrame.pps.length;
    
    body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);
    
    body[iIndex++] = 0x17;
    body[iIndex++] = 0x00;
    
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    body[iIndex++] = 0x00;
    
    body[iIndex++] = 0x01;
    body[iIndex++] = sps[1];
    body[iIndex++] = sps[2];
    body[iIndex++] = sps[3];
    body[iIndex++] = 0xff;
    
    /*sps*/
    body[iIndex++] = 0xe1;
    body[iIndex++] = (spsLen >> 8) & 0xff;
    body[iIndex++] = spsLen & 0xff;
    memcpy(&body[iIndex], sps, spsLen);
    iIndex += spsLen;
    
    /*pps*/
    body[iIndex++] = 0x01;
    body[iIndex++] = (ppsLen >> 8) & 0xff;
    body[iIndex++] = (ppsLen) & 0xff;
    memcpy(&body[iIndex], pps, ppsLen);
    iIndex += ppsLen;
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:iIndex nTimestamp:0];
    free(body);
}

- (void)sendVideo:(LFVideoFrame *)frame {
    if (_seiData) {
        [self sendSeiAndVideo:frame];
        _seiData = nil;
        return;
    }
    
    NSInteger i = 0;
    NSInteger rtmpLength = frame.data.length + 9;
    if (frame.isKeyFrame && frame.sps && frame.pps) {
        NSInteger spsLen = frame.sps.length;
        NSInteger ppsLen = frame.pps.length;
        rtmpLength += 8 + spsLen + ppsLen;
    }
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);
    
    if (frame.isKeyFrame) {
        body[i++] = 0x17;        // 1:Iframe  7:AVC
    } else {
        body[i++] = 0x27;        // 2:Pframe  7:AVC
    }
    body[i++] = 0x01;    // AVC NALU
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    
    if (frame.isKeyFrame && frame.sps && frame.pps) {
        /*sps*/
        NSInteger spsLen = frame.sps.length;
        body[i++] = (spsLen >> 24) & 0xff;
        body[i++] = (spsLen >> 16) & 0xff;
        body[i++] = (spsLen >>  8) & 0xff;
        body[i++] = (spsLen) & 0xff;
        memcpy(&body[i], frame.sps.bytes, spsLen);
        i += spsLen;
        
        /*pps*/
        NSInteger ppsLen = frame.pps.length;
        body[i++] = (ppsLen >> 24) & 0xff;
        body[i++] = (ppsLen >> 16) & 0xff;
        body[i++] = (ppsLen >>  8) & 0xff;
        body[i++] = (ppsLen) & 0xff;
        memcpy(&body[i], frame.pps.bytes, ppsLen);
        i += ppsLen;
    }
    
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length) & 0xff;
    memcpy(&body[i], frame.data.bytes, frame.data.length);
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    free(body);
}

- (void)sendSeiWithJson:(NSData *)data {
    _seiData = data;
}

void
print_bytes(void   *start,
            size_t  length)
{
    uint8_t *base = NULL;
    size_t   idx = 0;
    
    if (!start || length <= 0)
        return;
    
    base = (uint8_t *)(start);
    for (idx = 0; idx < length; idx++)
        printf("%02X%s", base[idx] & 0xFF, (idx + 1) % 16 == 0 ? "\n" : " ");
    printf("\n");
}

- (void)sendSeiAndVideo:(LFVideoFrame *)frame {
    /* 17.Media System Time Synchronization UUID
     * 7627DFE0-4924-4084-B98D-F2C9444B8E98 */
    static const uint8_t app_17_uuid[] =
    {0x76, 0x27, 0xDF, 0xE0,
        0x49, 0x24, 0x40, 0x84,
        0xB9, 0x8D, 0xF2, 0xC9,
        0x44, 0x4B, 0x8E, 0x98};
    
    NSUInteger payloadSize = 16 + 1 + _seiData.length;
    NSUInteger payloadSizeLength = payloadSize / 255 + 1;
    
    NSUInteger nalulen = 2 + payloadSizeLength + payloadSize + 1;
    
    NSInteger i = 0;
    NSInteger rtmpLength = 5 + 4 + nalulen;
    rtmpLength += 4 + frame.data.length;
    
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);
    
    if (frame.isKeyFrame) {
        body[i++] = 0x17;        // 1:Iframe  7:AVC
    } else {
        body[i++] = 0x27;        // 2:Pframe  7:AVC
    }
    body[i++] = 0x01;    // AVC NALU
    body[i++] = 0x00;
    body[i++] = 0x00;
    body[i++] = 0x00;
    
    /* nalu length */
    body[i++] = (nalulen >> 24) & 0xff;
    body[i++] = (nalulen >> 16) & 0xff;
    body[i++] = (nalulen >>  8) & 0xff;
    body[i++] = (nalulen) & 0xff;
    
    /* SEI NALU header, user unregistered type, and payload size */
    body[i++] = 0x66;
    body[i++] = 0x05;
    NSUInteger size = payloadSize;
    while (size >= 255) {
        body[i++] = 0xff;
        size -= 255;
    }
    body[i++] = (uint8_t)size;
    
    /* UUID */
    memcpy(&body[i], app_17_uuid, sizeof(app_17_uuid));
    i += sizeof(app_17_uuid);
    
    /* content type */
    body[i++] = 0x01;
    
    /* data */
    memcpy(&body[i], _seiData.bytes, _seiData.length);
    i += _seiData.length;
    
    /* rbsp_trailing_bits */
    body[i++] = 0x80;
    
    //    NSLog(@"send sei");
    //    print_bytes(body, rtmpLength - 4 - frame.data.length);
    
    // video frame
    body[i++] = (frame.data.length >> 24) & 0xff;
    body[i++] = (frame.data.length >> 16) & 0xff;
    body[i++] = (frame.data.length >>  8) & 0xff;
    body[i++] = (frame.data.length) & 0xff;
    memcpy(&body[i], frame.data.bytes, frame.data.length);
    i += frame.data.length;
    
    [self sendPacket:RTMP_PACKET_TYPE_VIDEO data:body size:(rtmpLength) nTimestamp:frame.timestamp];
    free(body);
}

- (BOOL)sendPacket:(unsigned int)nPacketType data:(unsigned char *)data size:(NSInteger)size nTimestamp:(uint64_t)nTimestamp {
    NSInteger rtmpLength = size;
    PILI_RTMPPacket rtmp_pack;
    PILI_RTMPPacket_Reset(&rtmp_pack);
    PILI_RTMPPacket_Alloc(&rtmp_pack, (uint32_t)rtmpLength);
    
    rtmp_pack.m_nBodySize = (uint32_t)size;
    memcpy(rtmp_pack.m_body, data, size);
    rtmp_pack.m_hasAbsTimestamp = 0;
    rtmp_pack.m_packetType = nPacketType;
    if (_rtmp) rtmp_pack.m_nInfoField2 = _rtmp->m_stream_id;
    rtmp_pack.m_nChannel = 0x04;
    rtmp_pack.m_headerType = RTMP_PACKET_SIZE_LARGE;
    if (RTMP_PACKET_TYPE_AUDIO == nPacketType && size != 4) {
        rtmp_pack.m_headerType = RTMP_PACKET_SIZE_MEDIUM;
    }
    rtmp_pack.m_nTimeStamp = (uint32_t)nTimestamp;

    BOOL nRet = [self RtmpPacketSend:&rtmp_pack];
    PILI_RTMPPacket_Free(&rtmp_pack);
    return nRet;
}

- (BOOL)RtmpPacketSend:(PILI_RTMPPacket *)packet {
    if (_rtmp && PILI_RTMP_IsConnected(_rtmp)) {
        bool success = PILI_RTMP_SendPacket(_rtmp, packet, 0, &_error);
        return (success == TRUE);
    }
    return NO;
}

- (void)sendAudioHeader:(LFAudioFrame *)audioFrame {
    
    NSInteger rtmpLength = audioFrame.audioInfo.length + 2;     /*spec data长度,一般是2*/
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);
    
    /*AF 00 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x00;
    memcpy(&body[2], audioFrame.audioInfo.bytes, audioFrame.audioInfo.length);          /*spec_buf是AAC sequence header数据*/
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:0];
    free(body);
}

- (void)sendAudio:(LFFrame *)frame {
    
    NSInteger rtmpLength = frame.data.length + 2;    /*spec data长度,一般是2*/
    unsigned char *body = (unsigned char *)malloc(rtmpLength);
    memset(body, 0, rtmpLength);
    
    /*AF 01 + AAC RAW data*/
    body[0] = 0xAF;
    body[1] = 0x01;
    memcpy(&body[2], frame.data.bytes, frame.data.length);
    [self sendPacket:RTMP_PACKET_TYPE_AUDIO data:body size:rtmpLength nTimestamp:frame.timestamp];
    free(body);
}

// 断线重连
- (void)reconnect {
    dispatch_async(self.rtmpSendQueue, ^{
        if (self.retryTimes4netWorkBreaken++ < self.reconnectCount && !self.isReconnecting) {
            self.isConnected = NO;
            self.isConnecting = NO;
            self.isReconnecting = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                 [self performSelector:@selector(_delayedReconnect) withObject:nil afterDelay:self.reconnectInterval];
            });
            
        } else if (self.retryTimes4netWorkBreaken >= self.reconnectCount) {
            if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
                [self.delegate socketStatus:self status:LFLiveError];
            }
            if (self.delegate && [self.delegate respondsToSelector:@selector(socketDidError:errorCode:)]) {
                [self.delegate socketDidError:self errorCode:LFLiveSocketError_ReConnectTimeOut];
            }
            [self forwardRTMPErrorIfNeeded];
        }
    });
}

- (void)_delayedReconnect {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];

    dispatch_async(self.rtmpSendQueue, ^{
	    [self _reconnect];
    });
}

- (void)_reconnect {

    _isReconnecting = NO;
    if (_isConnected) return;
    
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
        _rtmp = NULL;
    }
    _sendAudioHead = NO;
    _sendVideoHead = NO;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketStatus:status:)]) {
        [self.delegate socketStatus:self status:LFLiveRefresh];
    }
    
    if (_rtmp != NULL) {
        PILI_RTMP_Close(_rtmp, &_error);
        PILI_RTMP_Free(_rtmp);
    }
    [self RTMP264_Connect:_stream.url tcUrl:_stream.tcUrl];
}

- (void)forwardRTMPErrorIfNeeded {
    if (_error.code < 0) {
        NSInteger code = _error.code;
        NSString *message = [NSString stringWithUTF8String:_error.message];
        if (self.delegate && [self.delegate respondsToSelector:@selector(socketRTMPError:errorCode:message:)]) {
            [self.delegate socketRTMPError:self errorCode:code message:message];
        }
    }
}

- (void)forwardRTMPError:(RTMPError *)error {
    NSInteger code = error->code;
    NSString *message = [NSString stringWithUTF8String:error->message];
    if (self.delegate && [self.delegate respondsToSelector:@selector(socketRTMPError:errorCode:message:)]) {
        [self.delegate socketRTMPError:self errorCode:code message:message];
    }
}


#pragma mark -- CallBack
void RTMPErrorCallback(RTMPError *error, void *userData) {
    LFStreamRTMPSocket *socket = (__bridge LFStreamRTMPSocket *)userData;
    if (error->code < 0) {
//        [socket reconnect];
        [socket forwardRTMPError:error];
    }
}

void ConnectionTimeCallback(PILI_CONNECTION_TIME *conn_time, void *userData) {
}

#pragma mark -- LFStreamingBufferDelegate
- (void)streamingBuffer:(nullable LFStreamingBuffer *)buffer bufferState:(LFLiveBuffferState)state{
    if(self.delegate && [self.delegate respondsToSelector:@selector(socketBufferStatus:status:)]){
        [self.delegate socketBufferStatus:self status:state];
    }
}

#pragma mark -- Observer
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if([keyPath isEqualToString:@"isSending"]){
        if(!self.isSending){
            [self sendFrame];
        }
    }
}

#pragma mark -- Getter Setter

- (LFStreamingBuffer *)buffer {
    if (!_buffer) {
        _buffer = [[LFStreamingBuffer alloc] init];
        _buffer.delegate = self;
        
    }
    return _buffer;
}

- (LFLiveDebug *)debugInfo {
    if (!_debugInfo) {
        _debugInfo = [[LFLiveDebug alloc] init];
    }
    return _debugInfo;
}

- (dispatch_queue_t)rtmpSendQueue{
    if(!_rtmpSendQueue){
        _rtmpSendQueue = dispatch_queue_create("com.youku.LaiFeng.RtmpSendQueue", NULL);
    }
    return _rtmpSendQueue;
}

@end
