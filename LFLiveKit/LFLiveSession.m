//
//  LFLiveSession.m
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFLiveSession.h"
#import "LFVideoCapture.h"
#import "LFAudioCapture.h"
#import "LFHardwareVideoEncoder.h"
#import "LFHardwareAudioEncoder.h"
#import "LFH264VideoEncoder.h"
#import "LFStreamRTMPSocket.h"
#import "LFLiveStreamInfo.h"
#import "LFGPUImageBeautyFilter.h"
#import "LFH264VideoEncoder.h"


@interface LFLiveSession ()<LFAudioCaptureDelegate, LFVideoCaptureDelegate, LFAudioEncodingDelegate, LFVideoEncodingDelegate, LFStreamSocketDelegate>

/// 音频配置
@property (nonatomic, strong) LFLiveAudioConfiguration *audioConfiguration;
/// 视频配置
@property (nonatomic, strong) LFLiveVideoConfiguration *videoConfiguration;
/// 声音采集
@property (nonatomic, strong) LFAudioCapture *audioCaptureSource;
/// 视频采集
@property (nonatomic, strong) LFVideoCapture *videoCaptureSource;
/// 音频编码
@property (nonatomic, strong) id<LFAudioEncoding> audioEncoder;
/// 视频编码
@property (nonatomic, strong) id<LFVideoEncoding> videoEncoder;
/// 上传
@property (nonatomic, strong) id<LFStreamSocket> socket;


#pragma mark -- 内部标识
/// 调试信息
@property (nonatomic, strong) LFLiveDebug *debugInfo;
/// 流信息
@property (nonatomic, strong) LFLiveStreamInfo *streamInfo;
/// 是否开始上传
@property (nonatomic, assign) BOOL uploading;
/// 当前状态
@property (nonatomic, assign, readwrite) LFLiveState state;
/// 当前直播type
@property (nonatomic, assign, readwrite) LFLiveCaptureTypeMask captureType;

/// 时间戳锁
@property (nonatomic, strong) dispatch_semaphore_t lock;

@end

/**  时间戳 */
#define NOW (CACurrentMediaTime()*1000)
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@interface LFLiveSession ()

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) uint64_t currentTimestamp;

@end

@implementation LFLiveSession

#pragma mark -- LifeCycle
- (instancetype)initWithAudioConfiguration:(LFLiveAudioConfiguration *)audioConfiguration videoConfiguration:(LFLiveVideoConfiguration *)videoConfiguration {
    return [self initWithAudioConfiguration:audioConfiguration videoConfiguration:videoConfiguration captureType:LFLiveCaptureDefaultMask];
}

- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)audioConfiguration videoConfiguration:(nullable LFLiveVideoConfiguration *)videoConfiguration captureType:(LFLiveCaptureTypeMask)captureType{
    if((captureType & LFLiveCaptureMaskAudio || captureType & LFLiveInputMaskAudio) && !audioConfiguration) @throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"audioConfiguration is nil " userInfo:nil];
    if((captureType & LFLiveCaptureMaskVideo || captureType & LFLiveInputMaskVideo) && !videoConfiguration) @throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"videoConfiguration is nil " userInfo:nil];
    if (self = [super init]) {
        _audioConfiguration = audioConfiguration;
        _videoConfiguration = videoConfiguration;
        _adaptiveBitrate = NO;
        _isFirstFrame = YES;
        _captureType = captureType;
    }
    return self;
}

- (void)dealloc {
    self.videoCaptureSource.running = NO;
    self.audioCaptureSource.running = NO;
}

#pragma mark -- CustomMethod
- (void)startLive:(LFLiveStreamInfo *)streamInfo {
    if (!streamInfo) return;
    _streamInfo = streamInfo;
    _streamInfo.videoConfiguration = _videoConfiguration;
    _streamInfo.audioConfiguration = _audioConfiguration;
    _streamInfo.needDropFrame = (self.captureType & LFLiveCaptureMaskVideo || self.captureType & LFLiveInputMaskVideo) ? YES : NO;//< 有视频执行丢帧算法
    [self.socket start];
}

- (void)stopLive {
    self.uploading = NO;
    [self.socket stop];
    self.socket = nil;
}

- (void)pushVideo:(CVPixelBufferRef)pixelBuffer{
    if(self.captureType & LFLiveInputMaskVideo){
        if (self.uploading) [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:self.currentTimestamp];
    }
}

- (void)pushAudio:(AudioBufferList)audioBufferList{
    if(self.captureType & LFLiveInputMaskAudio){
        if (self.uploading) [self.audioEncoder encodeAudioData:audioBufferList timeStamp:self.currentTimestamp];
    }
}

#pragma mark -- CaptureDelegate
- (void)captureOutput:(nullable LFAudioCapture *)capture audioBuffer:(AudioBufferList)inBufferList {
    if (self.uploading) [self.audioEncoder encodeAudioData:inBufferList timeStamp:self.currentTimestamp];
}

- (void)captureOutput:(nullable LFVideoCapture *)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer {
    if (self.uploading) [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:self.currentTimestamp];
}

#pragma mark -- EncoderDelegate
- (void)audioEncoder:(nullable id<LFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame *)frame {
    if (self.uploading) [self.socket sendFrame:frame];  //<上传
}

- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame *)frame {
    if (self.uploading) [self.socket sendFrame:frame];  //<上传
}

#pragma mark -- LFStreamTcpSocketDelegate
- (void)socketStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveState)status {
    if (status == LFLiveStart) {
        if (!self.uploading) {
            self.timestamp = 0;
            self.isFirstFrame = YES;
            self.uploading = YES;
        }
    } else if(status == LFLiveStop || status == LFLiveError){
        self.uploading = NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = status;
        if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:liveStateDidChange:)]) {
            [self.delegate liveSession:self liveStateDidChange:status];
        }
    });
}

- (void)socketDidError:(nullable id<LFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:errorCode:)]) {
            [self.delegate liveSession:self errorCode:errorCode];
        }
    });
}

- (void)socketDebug:(nullable id<LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug *)debugInfo {
    self.debugInfo = debugInfo;
    if (self.showDebugInfo) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:debugInfo:)]) {
                [self.delegate liveSession:self debugInfo:debugInfo];
            }
        });
    }
}

- (void)socketBufferStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveBuffferState)status {
    if((self.captureType & LFLiveCaptureMaskVideo || self.captureType & LFLiveInputMaskVideo) && self.adaptiveBitrate){
        NSUInteger videoBitRate = [self.videoEncoder videoBitRate];
        if (status == LFLiveBuffferDecline) {
            if (videoBitRate < _videoConfiguration.videoMaxBitRate) {
                videoBitRate = videoBitRate + 50 * 1000;
                [self.videoEncoder setVideoBitRate:videoBitRate];
                NSLog(@"Increase bitrate %@", @(videoBitRate));
            }
        } else {
            if (videoBitRate > self.videoConfiguration.videoMinBitRate) {
                videoBitRate = videoBitRate - 100 * 1000;
                [self.videoEncoder setVideoBitRate:videoBitRate];
                NSLog(@"Decline bitrate %@", @(videoBitRate));
            }
        }
    }
}

#pragma mark -- Getter Setter
- (void)setRunning:(BOOL)running {
    if (_running == running) return;
    [self willChangeValueForKey:@"running"];
    _running = running;
    [self didChangeValueForKey:@"running"];
    self.videoCaptureSource.running = _running;
    self.audioCaptureSource.running = _running;
}

- (void)setPreView:(UIView *)preView {
    [self willChangeValueForKey:@"preView"];
    [self.videoCaptureSource setPreView:preView];
    [self didChangeValueForKey:@"preView"];
}

- (UIView *)preView {
    return self.videoCaptureSource.preView;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition {
    [self willChangeValueForKey:@"captureDevicePosition"];
    [self.videoCaptureSource setCaptureDevicePosition:captureDevicePosition];
    [self didChangeValueForKey:@"captureDevicePosition"];
}

- (AVCaptureDevicePosition)captureDevicePosition {
    return self.videoCaptureSource.captureDevicePosition;
}

- (void)setBeautyFace:(BOOL)beautyFace {
    [self willChangeValueForKey:@"beautyFace"];
    [self.videoCaptureSource setBeautyFace:beautyFace];
    [self didChangeValueForKey:@"beautyFace"];
}

- (BOOL)beautyFace {
    return self.videoCaptureSource.beautyFace;
}

- (void)setBeautyLevel:(CGFloat)beautyLevel {
    [self willChangeValueForKey:@"beautyLevel"];
    [self.videoCaptureSource setBeautyLevel:beautyLevel];
    [self didChangeValueForKey:@"beautyLevel"];
}

- (CGFloat)beautyLevel {
    return self.videoCaptureSource.beautyLevel;
}

- (void)setBrightLevel:(CGFloat)brightLevel {
    [self willChangeValueForKey:@"brightLevel"];
    [self.videoCaptureSource setBrightLevel:brightLevel];
    [self didChangeValueForKey:@"brightLevel"];
}

- (CGFloat)brightLevel {
    return self.videoCaptureSource.brightLevel;
}

- (void)setZoomScale:(CGFloat)zoomScale {
    [self willChangeValueForKey:@"zoomScale"];
    [self.videoCaptureSource setZoomScale:zoomScale];
    [self didChangeValueForKey:@"zoomScale"];
}

- (CGFloat)zoomScale {
    return self.videoCaptureSource.zoomScale;
}

- (void)setTorch:(BOOL)torch {
    [self willChangeValueForKey:@"torch"];
    [self.videoCaptureSource setTorch:torch];
    [self didChangeValueForKey:@"torch"];
}

- (BOOL)torch {
    return self.videoCaptureSource.torch;
}

- (void)setMirror:(BOOL)mirror {
    [self willChangeValueForKey:@"mirror"];
    [self.videoCaptureSource setMirror:mirror];
    [self didChangeValueForKey:@"mirror"];
}

- (BOOL)mirror {
    return self.videoCaptureSource.mirror;
}

- (void)setMuted:(BOOL)muted {
    [self willChangeValueForKey:@"muted"];
    [self.audioCaptureSource setMuted:muted];
    [self didChangeValueForKey:@"muted"];
}

- (BOOL)muted {
    return self.audioCaptureSource.muted;
}

- (void)setWarterMarkView:(UIView *)warterMarkView{
    [self.videoCaptureSource setWarterMarkView:warterMarkView];
}

- (UIView*)warterMarkView{
    return self.videoCaptureSource.warterMarkView;
}

- (LFAudioCapture *)audioCaptureSource {
    if (!_audioCaptureSource) {
        if(self.captureType & LFLiveCaptureMaskAudio){
            _audioCaptureSource = [[LFAudioCapture alloc] initWithAudioConfiguration:_audioConfiguration];
            _audioCaptureSource.delegate = self;
        }
    }
    return _audioCaptureSource;
}

- (LFVideoCapture *)videoCaptureSource {
    if (!_videoCaptureSource) {
        if(self.captureType & LFLiveCaptureMaskVideo){
            _videoCaptureSource = [[LFVideoCapture alloc] initWithVideoConfiguration:_videoConfiguration];
            _videoCaptureSource.delegate = self;
        }
    }
    return _videoCaptureSource;
}

- (id<LFAudioEncoding>)audioEncoder {
    if (!_audioEncoder) {
        _audioEncoder = [[LFHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:_audioConfiguration];
        [_audioEncoder setDelegate:self];
    }
    return _audioEncoder;
}

- (id<LFVideoEncoding>)videoEncoder {
    if (!_videoEncoder) {
        if([[UIDevice currentDevice].systemVersion floatValue] < 8.0){
            _videoEncoder = [[LFH264VideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
        }else{
            _videoEncoder = [[LFHardwareVideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
        }
        [_videoEncoder setDelegate:self];
    }
    return _videoEncoder;
}

- (id<LFStreamSocket>)socket {
    if (!_socket) {
        _socket = [[LFStreamRTMPSocket alloc] initWithStream:self.streamInfo reconnectInterval:self.reconnectInterval reconnectCount:self.reconnectCount];
        [_socket setDelegate:self];
    }
    return _socket;
}

- (LFLiveStreamInfo *)streamInfo {
    if (!_streamInfo) {
        _streamInfo = [[LFLiveStreamInfo alloc] init];
    }
    return _streamInfo;
}

- (dispatch_semaphore_t)lock{
    if(!_lock){
        _lock = dispatch_semaphore_create(1);
    }
    return _lock;
}

- (uint64_t)currentTimestamp {
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if (_isFirstFrame) {
        _timestamp = NOW;
        _isFirstFrame = NO;
        currentts = 0;
    } else {
        currentts = NOW - _timestamp;
    }
    dispatch_semaphore_signal(self.lock);
    return currentts;
}

@end
