//
//  LFLiveSession.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
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
#import "LFStreamLog.h"
#import "RKVideoCapture.h"
#import "RKAudioMix.h"
#import "RKReplayKitCapture.h"

@interface LFLiveSession ()<LFAudioCaptureDelegate, LFVideoCaptureInterfaceDelegate, LFAudioEncodingDelegate, LFVideoEncodingDelegate, LFStreamSocketDelegate, RKReplayKitCaptureDelegate>

/// 音频配置
@property (nonatomic, strong) LFLiveAudioConfiguration *audioConfiguration;
/// 视频配置
@property (nonatomic, strong) LFLiveVideoConfiguration *videoConfiguration;
/// 声音采集
@property (nonatomic, strong) LFAudioCapture *audioCaptureSource;
/// 视频采集
@property (nonatomic, strong) id<LFVideoCaptureInterface> videoCaptureSource;
/// 音频编码
@property (nonatomic, strong) id<LFAudioEncoding> audioEncoder;
/// 视频编码
@property (nonatomic, strong) id<LFVideoEncoding> videoEncoder;
/// 上传
@property (nonatomic, strong) id<LFStreamSocket> socket;

@property (strong, nonatomic) RKReplayKitCapture *replayKitCapture;
@property (strong, nonatomic) NSMutableArray<LFVideoFrame *> *videoFrameQueue;


#pragma mark -- 内部标识
/// 调试信息
@property (nonatomic, copy) LFLiveDebug *debugInfo;
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

/// 上传相对时间戳
@property (nonatomic, assign) uint64_t relativeTimestamps;
/// 音视频是否对齐
@property (nonatomic, assign) BOOL AVAlignment;
/// 当前是否采集到了音频
@property (nonatomic, assign) BOOL hasCaptureAudio;
/// 当前是否采集到了关键帧
@property (nonatomic, assign) BOOL hasKeyFrameVideo;

@property (strong, nonatomic) NSURL *bgSoundURL;
@property (assign, nonatomic) LFAudioMixVolume bgSoundVolume;

@end

@implementation LFLiveSession

#pragma mark -- LifeCycle
- (instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)audioConfiguration
                        videoConfiguration:(nullable LFLiveVideoConfiguration *)videoConfiguration {
    return [self initWithAudioConfiguration:audioConfiguration
                         videoConfiguration:videoConfiguration captureType:LFLiveCaptureDefaultMask];
}

- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)audioConfiguration
                                 videoConfiguration:(nullable LFLiveVideoConfiguration *)videoConfiguration
                                        captureType:(LFLiveCaptureTypeMask)captureType {
    return [self initWithAudioConfiguration:audioConfiguration
                         videoConfiguration:videoConfiguration
                                captureType:captureType
                                eaglContext:nil];
}

- (nullable instancetype)initWithAudioConfiguration:(nullable LFLiveAudioConfiguration *)audioConfiguration
                                 videoConfiguration:(nullable LFLiveVideoConfiguration *)videoConfiguration
                                        captureType:(LFLiveCaptureTypeMask)captureType
                                        eaglContext:(EAGLContext *)glContext {
    if ((captureType & LFLiveCaptureMaskAudio || captureType & LFLiveInputMaskAudio) && !audioConfiguration)
        @throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"audioConfiguration is nil " userInfo:nil];
    if ((captureType & LFLiveCaptureMaskVideo || captureType & LFLiveInputMaskVideo) && !videoConfiguration)
        @throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"videoConfiguration is nil " userInfo:nil];
    if (self = [super init]) {
        _audioConfiguration = audioConfiguration;
        _videoConfiguration = videoConfiguration;
        _adaptiveBitrate = NO;
        _captureType = captureType;
        _glContext = glContext;
    }
    return self;
}

- (nullable instancetype)initForReplayKitBroadcast {
    if (self = [super init]) {
        _captureType = LFLiveInputMaskAll;
        _isReplayKitBroadcast = YES;
    }
    return self;
}

- (void)dealloc {
    _videoCaptureSource.running = NO;
    _audioCaptureSource.running = NO;
}

#pragma mark -- CustomMethod
- (void)startLive:(LFLiveStreamInfo *)streamInfo {
    if (!streamInfo) return;
    _streamInfo = streamInfo;
    _streamInfo.videoConfiguration = _videoConfiguration;
    _streamInfo.audioConfiguration = _audioConfiguration;
    
    [LFStreamLog logger].initStartTime = [NSDate date].timeIntervalSince1970;
    [[LFStreamLog logger] fetchInfo];
    __weak typeof(self) wSelf = self;
    [LFStreamLog logger].logCallback = ^(NSDictionary *dic) {
        if ([wSelf.delegate respondsToSelector:@selector(liveSession:log:)]) {
            [wSelf.delegate liveSession:wSelf log:dic];
        }
    };
    NSUInteger videoBitRate = [self.videoEncoder videoBitRate];
    [[LFStreamLog logger] logWithDict:@{@"lt" : @"pbrt",
                                        @"vbr": @(videoBitRate)}];
    
    [self.socket start];
}

- (void)stopLive {
    self.uploading = NO;
    [self.socket stop];
    self.socket = nil;
}

- (void)pushVideo:(nullable CVPixelBufferRef)pixelBuffer{
    if(self.captureType & LFLiveInputMaskVideo){
        if (self.uploading) [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:NOW];
    }
}

- (void)pushAudio:(nullable NSData*)audioData{
    if(self.captureType & LFLiveInputMaskAudio){
        if (self.uploading) [self.audioEncoder encodeAudioData:audioData timeStamp:NOW];
        
    } else if(self.captureType & LFLiveMixMaskAudioInputVideo) {
        if (audioData) {
            [self.audioCaptureSource mixSideData:audioData weight:LFAudioMixVolumeVeryHigh / 10.0];
        }
    }
}

- (BOOL)sendSeiJson:(nonnull id)jsonObj {
    if (self.uploading) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:jsonObj options:0 error:nil];
        if (data) {
            [self.socket sendSeiWithJson:data];
            return YES;
        }
    }
    return NO;
}

- (void)pushReplayKitSample:(nonnull CMSampleBufferRef)sampleBuffer type:(RKReplayKitSampleType)type {
    switch (type) {
        case RKReplayKitSampleTypeVideo:
            [self.replayKitCapture pushVideoSample:sampleBuffer];
            break;
        case RKReplayKitSampleTypeAppAudio:
            [self.replayKitCapture pushAppAudioSample:sampleBuffer];
            break;
        case RKReplayKitSampleTypeMicAudio:
            [self.replayKitCapture pushMicAudioSample:sampleBuffer];
            break;
    }
}

- (void)previousColorFilter {
    [self.videoCaptureSource previousColorFilter];
}

- (void)nextColorFilter {
    [self.videoCaptureSource nextColorFilter];
}

- (void)setTargetColorFilter:(NSInteger)targetIndex {
    [self.videoCaptureSource setTargetColorFilter:targetIndex];
}

- (void)playSound:(nonnull NSURL *)soundUrl {
    [self playSound:soundUrl volume:LFAudioMixVolumeHigh];
}

- (void)playSound:(nonnull NSURL *)soundUrl volume:(LFAudioMixVolume)volume {
    [self.audioCaptureSource mixSound:soundUrl weight:volume / 10.0];
}

- (void)playSoundSequences:(nonnull NSArray<NSURL *> *)urls {
    [self playSoundSequences:urls volume:LFAudioMixVolumeHigh];
}

- (void)playSoundSequences:(nonnull NSArray<NSURL *> *)urls volume:(LFAudioMixVolume)volume {
    [self.audioCaptureSource mixSoundSequences:urls weight:volume / 10.0];
}

- (void)playSoundSequences:(nonnull NSArray<NSURL *> *)urls interval:(NSTimeInterval)interval {
    [self playSoundSequences:urls];
}

- (void)playParallelSounds:(nonnull NSSet<NSURL *> *)urls {
    [self playParallelSounds:urls.allObjects volumes:nil];
}

- (void)playParallelSounds:(nonnull NSArray<NSURL *> *)urls volumes:(NSArray<NSNumber *> *)volumes {
    NSMutableArray<NSNumber *> *weights = [NSMutableArray new];
    for (int i = 0; i < urls.count; i++) {
        [weights addObject:i < volumes.count ? @(volumes[i].unsignedIntegerValue / 10.0) : @(LFAudioMixVolumeNormal / 10.0)];
    }
    [self.audioCaptureSource mixSounds:urls weights:weights];
}

- (void)startBackgroundSound:(nonnull NSURL *)soundUrl {
    [self startBackgroundSound:soundUrl volume:LFAudioMixVolumeVeryLow];
}

- (void)startBackgroundSound:(nonnull NSURL *)soundUrl volume:(LFAudioMixVolume)volume {
    self.bgSoundURL = soundUrl;
    self.bgSoundVolume = volume;
    [self.audioCaptureSource mixSound:soundUrl weight:volume / 10.0 repeated:YES];
}

- (void)stopBackgroundSound {
    [self.audioCaptureSource stopMixSound:self.bgSoundURL];
}

- (void)restartBackgroundSound {
    [self stopBackgroundSound];
    [self startBackgroundSound:self.bgSoundURL volume:self.bgSoundVolume];
}

- (void)stopAllSounds {
    [self.audioCaptureSource stopMixAllSounds];
}

- (BOOL)updateVideoBitRateWithMaxBitRate:(NSUInteger)maxBitRate minBitRate:(NSUInteger)minBitRate {
    if (!self.videoConfiguration || !self.videoEncoder ||
        (self.videoConfiguration.videoMinBitRate == minBitRate && self.videoConfiguration.videoMaxBitRate == maxBitRate)) {
        return NO;
    }
    
    NSUInteger currentBitRate = [self.videoEncoder videoBitRate];
    NSUInteger targetBitrate = currentBitRate;
    if (currentBitRate < minBitRate || currentBitRate > maxBitRate) {
        targetBitrate = (maxBitRate + minBitRate) / 2;
        [self.videoEncoder setVideoBitRate:targetBitrate];
        NSLog(@"Update bitrate %@", @(targetBitrate));
    }
    
    self.videoConfiguration.videoBitRate = targetBitrate;
    self.videoConfiguration.videoMinBitRate = minBitRate;
    self.videoConfiguration.videoMaxBitRate = maxBitRate;
    
    return YES;
}

#pragma mark -- PrivateMethod

- (void)pushSendBuffer:(LFFrame*)frame{
    if(self.relativeTimestamps == 0){
        self.relativeTimestamps = frame.timestamp;
    }
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    [self.socket sendFrame:frame];
}

#pragma mark -- Audio Capture Delegate

- (void)captureOutput:(nullable LFAudioCapture *)capture audioBeforeSideMixing:(nullable NSData *)data {
    if ([self.delegate respondsToSelector:@selector(liveSession:audioDataBeforeMixing:)]) {
        [self.delegate liveSession:self audioDataBeforeMixing:data];
    }
}

- (void)captureOutput:(nullable LFAudioCapture *)capture didFinishAudioProcessing:(nullable NSData *)data {
    if (self.uploading) {
        [self.audioEncoder encodeAudioData:data timeStamp:NOW];
    }
}

#pragma mark - Video Capture Delegate

- (void)captureOutput:(nullable id<LFVideoCaptureInterface>)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer atTime:(CMTime)time {
    if ([self.delegate respondsToSelector:@selector(liveSession:willOutputVideoFrame:atTime:)]) {
        pixelBuffer = [self.delegate liveSession:self willOutputVideoFrame:pixelBuffer atTime:time];
    }
    if (self.uploading) {
        [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:NOW];
    }
}

#pragma mark -- EncoderDelegate
- (void)audioEncoder:(nullable id<LFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame *)frame {
    if (!self.uploading) {
        return;
    }
    if (!self.hasCaptureAudio) {
        self.hasCaptureAudio = YES;
    }
    // replaykit broadcast should send audio frame without waiting AV alignment
    if (self.isReplayKitBroadcast || self.AVAlignment) {
        [self pushSendBuffer:frame];
    }
}

- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame *)frame {
    if (!self.uploading) {
        return;
    }
    if (self.isReplayKitBroadcast) {
        if (!_videoFrameQueue) {
            _videoFrameQueue = [NSMutableArray new];
        }
        [_videoFrameQueue addObject:frame];
        
        if (!self.hasKeyFrameVideo && frame.isKeyFrame) {
            self.hasKeyFrameVideo = YES;
        }
        // replaykit broadcast should wait audio available before sending queued video frame
        if (self.hasCaptureAudio) {
            // defer timestamp to match audio
            LFVideoFrame *frame = _videoFrameQueue.firstObject;
            frame.timestamp = _videoFrameQueue.lastObject.timestamp;
            [_videoFrameQueue removeObjectAtIndex:0];
            [self pushSendBuffer:frame];
        }
    } else {
        if (!self.hasKeyFrameVideo && frame.isKeyFrame && self.hasCaptureAudio) {
            self.hasKeyFrameVideo = YES;
        }
        if (self.AVAlignment) {
            [self pushSendBuffer:frame];
        }
    }
}

#pragma mark -- LFStreamTcpSocketDelegate
- (void)socketStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveState)status {
    if (status == LFLiveStart) {
        if (!self.uploading) {
            self.AVAlignment = NO;
            self.hasCaptureAudio = NO;
            self.hasKeyFrameVideo = NO;
            self.relativeTimestamps = 0;
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
    [[LFStreamLog logger] logWithDict:@{@"lt": @"pfld",
                                        @"er": @(errorCode)
                                        }];
}

- (void)socketDebug:(nullable id<LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug *)debugInfo {
    self.debugInfo = debugInfo;
    if (self.showDebugInfo) {
        __weak typeof(self) wSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([wSelf.delegate respondsToSelector:@selector(liveSession:debugInfo:)]) {
                [wSelf.delegate liveSession:wSelf debugInfo:wSelf.debugInfo];
            }
        });
    }
}

- (void)socketBufferStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveBuffferState)status {
    if((self.captureType & LFLiveCaptureMaskVideo || self.captureType & LFLiveInputMaskVideo) && self.adaptiveBitrate){
        NSUInteger videoBitRate = [self.videoEncoder videoBitRate];
        NSUInteger targetBitrate = videoBitRate;
        if (status == LFLiveBuffferDecline) {
            if (videoBitRate < _videoConfiguration.videoMaxBitRate) {
                targetBitrate = videoBitRate + 50 * 1000;
                [self.videoEncoder setVideoBitRate:targetBitrate];
                NSLog(@"Increase bitrate %@", @(targetBitrate));
            }
        } else {
            if (videoBitRate > self.videoConfiguration.videoMinBitRate) {
                targetBitrate = videoBitRate - 100 * 1000;
                [self.videoEncoder setVideoBitRate:targetBitrate];
                NSLog(@"Decline bitrate %@", @(targetBitrate));
            }
        }
        if (targetBitrate != videoBitRate) {
            [[LFStreamLog logger] logWithDict:@{@"lt": @"pbrt",
                                                @"vbr": @(targetBitrate)
                                                }];
        }
    }
}

#pragma mark - ReplayKitCapture Delegate

- (void)replayKitCapture:(RKReplayKitCapture *)capture didCaptureVideo:(CVPixelBufferRef)pixelBuffer {
    if (!_streamInfo.videoConfiguration) {
        _streamInfo.videoConfiguration = capture.videoConfiguration;
    }
    [self pushVideo:pixelBuffer];
}

- (void)replayKitCapture:(RKReplayKitCapture *)capture didCaptureAudio:(NSData *)data {
    if (!_streamInfo.audioConfiguration) {
        _streamInfo.audioConfiguration = capture.audioConfiguration;
    }
    [self pushAudio:data];
}

#pragma mark -- Getter Setter

// 17 media
- (void)setProvider:(NSString *)provider {
    [LFStreamLog logger].pd = provider;
}

- (void)setLiveId:(NSString *)liveId {
    [LFStreamLog logger].sid = liveId;
}

- (void)setUserId:(NSString *)userId {
    [LFStreamLog logger].uid = userId;
}

- (void)setLongitude:(double)longitude {
    [LFStreamLog logger].lnt = longitude;
}

- (void)setLatitude:(double)latitude {
    [LFStreamLog logger].ltt = latitude;
}

- (void)setRegion:(NSString *)region {
    [LFStreamLog logger].rg = region;
}

- (void)setAppVersion:(NSString *)appVersion {
    [LFStreamLog logger].av17 = appVersion;
}

- (NSDictionary *)logInfo {
    return [LFStreamLog logger].basicInfo;
}

- (NSString *)currentColorFilterName {
    return self.videoCaptureSource.currentColorFilterName;
}

- (NSInteger)currentColorFilterIndex {
    return self.videoCaptureSource.currentColorFilterIndex;
}

- (NSArray<NSString *> *)colorFilterNames {
    return self.videoCaptureSource.colorFilterNames;
}

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

- (BOOL)saveLocalVideo{
    return self.videoCaptureSource.saveLocalVideo;
}

- (void)setSaveLocalVideo:(BOOL)saveLocalVideo{
    [self.videoCaptureSource setSaveLocalVideo:saveLocalVideo];
}


- (NSURL*)saveLocalVideoPath{
    return self.videoCaptureSource.saveLocalVideoPath;
}

- (void)setSaveLocalVideoPath:(NSURL*)saveLocalVideoPath{
    [self.videoCaptureSource setSaveLocalVideoPath:saveLocalVideoPath];
}

- (BOOL)beautyFace {
    return self.videoCaptureSource.beautyFace;
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

- (void)setMirrorOutput:(BOOL)mirrorOutput {
    [self willChangeValueForKey:@"mirrorOutput"];
    [self.videoCaptureSource setMirrorOutput:mirrorOutput];
    [self didChangeValueForKey:@"mirrorOutput"];
}

- (BOOL)mirrorOutput {
    return self.videoCaptureSource.mirrorOutput;
}

- (void)setMuted:(BOOL)muted {
    [self willChangeValueForKey:@"muted"];
    [self.audioCaptureSource setMuted:muted];
    [self didChangeValueForKey:@"muted"];
}

- (BOOL)muted {
    return self.audioCaptureSource.muted;
}

- (void)setWatermarkView:(UIView *)watermarkView{
    [self.videoCaptureSource setWatermarkView:watermarkView];
}

- (nullable UIView *)watermarkView{
    return self.videoCaptureSource.watermarkView;
}

- (nullable UIImage *)currentImage{
    return self.videoCaptureSource.currentImage;
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

- (id<LFVideoCaptureInterface>)videoCaptureSource {
    if (!_videoCaptureSource) {
        if(self.captureType & LFLiveCaptureMaskVideo){
            if (_gpuimageOn) {
                _videoCaptureSource = [[LFVideoCapture alloc] initWithVideoConfiguration:_videoConfiguration];
                ((LFVideoCapture*)_videoCaptureSource).useAdvanceBeauty = _gpuimageAdvanceBeautyEnabled;
            } else {
                _videoCaptureSource = [[RKVideoCapture alloc] initWithVideoConfiguration:_videoConfiguration eaglContext:_glContext];
            }
            _videoCaptureSource.delegate = self;
        }
    }
    return _videoCaptureSource;
}

- (RKReplayKitCapture *)replayKitCapture {
    if (!_replayKitCapture) {
        if (_isReplayKitBroadcast) {
            _replayKitCapture = [[RKReplayKitCapture alloc] init];
            _replayKitCapture.delegate = self;
        }
    }
    return _replayKitCapture;
}

- (id<LFAudioEncoding>)audioEncoder {
    if (!_audioEncoder) {
        if (!_isReplayKitBroadcast) {
            _audioEncoder = [[LFHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:_audioConfiguration];
        } else {
            if (_replayKitCapture.audioConfiguration) {
                _audioEncoder = [[LFHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:_replayKitCapture.audioConfiguration];
            }
        }
        [_audioEncoder setDelegate:self];
    }
    return _audioEncoder;
}

- (id<LFVideoEncoding>)videoEncoder {
    if (!_videoEncoder) {
        if (!_isReplayKitBroadcast) {
            if ([[UIDevice currentDevice].systemVersion floatValue] < 8.0){
                _videoEncoder = [[LFH264VideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
            } else {
                _videoEncoder = [[LFHardwareVideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
            }
        } else {
            if (_replayKitCapture.videoConfiguration) {
                _videoEncoder = [[LFHardwareVideoEncoder alloc] initWithVideoStreamConfiguration:_replayKitCapture.videoConfiguration];
            }
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

- (uint64_t)uploadTimestamp:(uint64_t)captureTimestamp{
    dispatch_semaphore_wait(self.lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    currentts = captureTimestamp - self.relativeTimestamps;
    dispatch_semaphore_signal(self.lock);
    return MAX(currentts, 0);
}

- (BOOL)AVAlignment{
    if((self.captureType & LFLiveCaptureMaskAudio || self.captureType & LFLiveInputMaskAudio) &&
       (self.captureType & LFLiveCaptureMaskVideo || self.captureType & LFLiveInputMaskVideo)
       ){
        if(self.hasCaptureAudio && self.hasKeyFrameVideo) return YES;
        else  return NO;
    }else{
        return YES;
    }
}

@end
