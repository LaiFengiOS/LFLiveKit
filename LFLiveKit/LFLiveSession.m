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
#import "BitrateHandler.h"

@implementation UIImage (Resize)
- (UIImage *)scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [self drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
@end


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

/// 是否要停止將採集到的video/audio data做encode, 沒有encoded的data就不會推送到rtmp
@property (assign, nonatomic) BOOL stopEncodingVideoAudioData;

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

@property (nonatomic, assign, readwrite) LFLiveInternetState internetSignal;
@property (nonatomic, strong) BitrateHandler *bitrateHandler;

@property (nonatomic) CVPixelBufferRef backgroundPlaceholder;
@property (nonatomic, strong) dispatch_source_t timer;
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
        if (videoConfiguration) {
            _bitrateHandler = [[BitrateHandler alloc] initWithAvg:videoConfiguration.videoBitRate
                                                              max:videoConfiguration.videoMaxBitRate
                                                              min:videoConfiguration.videoMinBitRate
                                                            count:5];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];

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
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    _videoCaptureSource.running = NO;
    _audioCaptureSource.running = NO;
    _bitrateHandler.bitrateShouldChangeBlock = nil;
}
#pragma mark - Notification

- (void)willEnterBackground:(NSNotification *)notification {
    CGFloat frameRate = _videoConfiguration.videoFrameRate;
    CGFloat frameTime = 1 / frameRate;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, 0), frameTime * NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(self.timer, ^{
        [self sendVideoPlaceholder];
    });
    dispatch_resume(self.timer);
}

- (void)willEnterForeground:(NSNotification *)notification {
    dispatch_cancel(self.timer);
    self.timer = nil;
}

- (void)sendVideoPlaceholder {
    if ((self.uploading) && (self.backgroundPlaceholder)) {
        [self.videoEncoder encodeVideoData:self.backgroundPlaceholder timeStamp:NOW];
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        });
    }
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

- (BOOL)updateStreamURL:(nonnull NSString *)url tcURL:(nonnull NSString *)tcurl {
    //([_streamInfo.url isEqualToString:url] && [_streamInfo.tcUrl isEqualToString:tcurl]) ||
    // remove checking url part, to force reconnnect when update stream url
    if (!_socket || ![_socket respondsToSelector:@selector(streamURLChanged:tcurl:)]) {
        return NO;
    }
    
    _streamInfo.url = url;
    _streamInfo.tcUrl = tcurl;
    if ([self.videoEncoder respondsToSelector:@selector(reset)]) {
        [self.videoEncoder reset];
    }
    
    [_socket streamURLChanged:url tcurl:tcurl];
    
    return YES;
}

- (void)pauseLive {
    if (self.stopEncodingVideoAudioData == YES) {
        return;
    }
    
    [self.socket switched];
    self.socket = nil;
    
    self.stopEncodingVideoAudioData = YES;
}

- (void)resumeLive:(nonnull NSString *)pushURL {
    if (self.stopEncodingVideoAudioData == NO) {
        return;
    }
    
    _streamInfo.url = pushURL;
    if ([self.videoEncoder respondsToSelector:@selector(reset)]) {
        [self.videoEncoder reset];
    }
    [self.socket streamURLChanged:pushURL tcurl:_streamInfo.tcUrl];
    
    self.stopEncodingVideoAudioData = NO;
}

- (void)stopLive {
    self.uploading = NO;
    [self.socket stop];
    self.socket = nil;
}

- (void)pushVideo:(nullable CVPixelBufferRef)pixelBuffer {
    if (self.captureType & LFLiveInputMaskVideo) {
        if (self.uploading) {
            [self checkResolutionChange:pixelBuffer];
            [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:NOW];
        }
    }
}

- (void)pushAudio:(nullable NSData *)audioData {
    if (self.captureType & LFLiveInputMaskAudio) {
        if (self.uploading) [self.audioEncoder encodeAudioData:audioData timeStamp:NOW];
        
    } else if (self.captureType & LFLiveMixMaskAudioInputVideo) {
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

- (void)playParallelSounds:(nonnull NSArray<NSURL *> *)urls volumes:(nullable NSArray<NSNumber *> *)volumes {
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

- (void)updateVideoConfiguration:(LFLiveVideoConfiguration *)videoConfiguration {
    if (!_videoConfiguration || !_videoEncoder) {
        return;
    }
    
    if ([self.videoCaptureSource respondsToSelector:@selector(setNextVideoConfiguration:)]) {
        ((RKVideoCapture *)self.videoCaptureSource).nextVideoConfiguration = videoConfiguration;
    }
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
    frame.timestamp = [self uploadTimestamp:frame.timestamp];
    [self.socket sendFrame:frame];
}

- (void)checkResolutionChange:(nullable CVPixelBufferRef)pixelBuffer {
    if (![self.videoEncoder respondsToSelector:@selector(reset)] || !pixelBuffer) {
        return;
    }
    
    CGSize videoSize = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
    if (!_streamInfo || CGSizeEqualToSize(_streamInfo.videoConfiguration.videoSize, videoSize)) {
        return;
    }
    
    _streamInfo.videoConfiguration.videoSize = videoSize;
    [self.videoEncoder reset];
}

- (void)checkInternetConditionIfChanged {
    // To skip the empty frame input for calculating internet status. 
    if (self.debugInfo.currentCapturedVideoCount == 0) {
        return;
    }
    //Using configuration's Video Bitrate. If need to use encoder's bitrate, just change to self.videoEncoder.
    // * 0.125 is in order to convert bits to btyes. 0.75 is custom boundary for intenrnet edge.
    BOOL isLower = self.debugInfo.currentBandwidth < (self.videoConfiguration.videoBitRate * 0.125 * 0.75);
    LFLiveInternetState newState = isLower ? LFLiveInternetStateLow : LFLiveInternetStateNormal;
    if (self.internetSignal != newState) {
        self.internetSignal = newState;
        if ([self.delegate respondsToSelector:@selector(liveSession:signalChanged:)]) {
            [self.delegate liveSession:self signalChanged:newState];
        }
    }
}

- (void)adaptVideoBitrate:(NSUInteger)expected {
    if((self.captureType & LFLiveCaptureMaskVideo || self.captureType & LFLiveInputMaskVideo) && self.adaptiveBitrate){
        NSUInteger videoBitRate = [self.videoEncoder videoBitRate];
        NSUInteger currentBitrate = videoBitRate;
        if (expected == currentBitrate) {
            return;
        }
        
#if DEBUG
        NSLog(@"change bitrate !!!! %@", @(expected));
#endif
        [self.videoEncoder setVideoBitRate:expected];
          
        [[LFStreamLog logger] logWithDict:@{
            @"lt": @"pbrt",
            @"vbr": @(expected)
        }];
    }
}

- (void)setupBitrateHandleCallback {
    __weak typeof(self) weakSelf = self;
    self.bitrateHandler.bitrateShouldChangeBlock = ^(NSUInteger bitrate){
        [weakSelf adaptVideoBitrate:bitrate];
    };
}

#pragma mark -- Audio Capture Delegate

- (void)captureOutput:(nullable LFAudioCapture *)capture audioBeforeSideMixing:(nullable NSData *)data {
    if ([self.delegate respondsToSelector:@selector(liveSession:audioDataBeforeMixing:)]) {
        [self.delegate liveSession:self audioDataBeforeMixing:data];
    }
}

- (void)captureOutput:(nullable LFAudioCapture *)capture didFinishAudioProcessing:(AudioBufferList)buffers samples:(NSUInteger)samples {
    if ([self.delegate respondsToSelector:@selector(liveSession:willOutputAudioFrame:samples:customTime:)]) {
        [self.delegate liveSession:self willOutputAudioFrame:(unsigned char *)buffers.mBuffers[0].mData samples:samples customTime:NOW];
    }
    
    if (self.uploading && !self.stopEncodingVideoAudioData) {
        NSData *data = [NSData dataWithBytes:buffers.mBuffers[0].mData length:buffers.mBuffers[0].mDataByteSize];
        [self.audioEncoder encodeAudioData:data timeStamp:NOW];
    }
}

#pragma mark - Video Capture Delegate

- (void)captureOutput:(nullable id<LFVideoCaptureInterface>)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer atTime:(CMTime)time didUpdateVideoConfiguration:(BOOL)didUpdateVideoConfiguration {
    if (didUpdateVideoConfiguration && [self.videoEncoder respondsToSelector:@selector(reset)]) {
        [self.videoEncoder reset];
    }

    if ([self.delegate respondsToSelector:@selector(liveSession:willOutputVideoFrame:atTime:customTime:didUpdateVideConfiguration:)]) {
        pixelBuffer = [self.delegate liveSession:self willOutputVideoFrame:pixelBuffer atTime:time customTime:NOW didUpdateVideConfiguration:didUpdateVideoConfiguration];
    }
    
    if (self.uploading && !self.stopEncodingVideoAudioData && !didUpdateVideoConfiguration) {
        [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:NOW];
    }
}

- (void)captureRawCamera:(nullable id<LFVideoCaptureInterface>)capture pixelBuffer:(nullable CVPixelBufferRef)pixelBuffer atTime:(CMTime)time {
    if ([self.delegate respondsToSelector:@selector(liveSession:rawCameraVideoFrame:atTime:)]) {
        [self.delegate liveSession:self rawCameraVideoFrame:pixelBuffer atTime:time];
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
- (void)socketDidPublishSucceed:(id<LFStreamSocket>)socket {
    if ([self.delegate respondsToSelector:@selector(liveSessionDidSucceedRTMP:)]) {
        [self.delegate liveSessionDidSucceedRTMP:self];
    }
}

- (void)socketStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveState)status {
    if (status == LFLiveStart) {
        if (!self.uploading) {
            self.AVAlignment = NO;
            self.hasCaptureAudio = NO;
            self.hasKeyFrameVideo = NO;
            self.relativeTimestamps = 0;
            self.uploading = YES;
        }
    } else if(status == LFLiveStop || status == LFLiveError || status == LFLiveSwitched) {
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
    [self checkInternetConditionIfChanged];
    if (self.showDebugInfo) {
        __weak typeof(self) wSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([wSelf.delegate respondsToSelector:@selector(liveSession:debugInfo:)]) {
                [wSelf.delegate liveSession:wSelf debugInfo:wSelf.debugInfo];
            }
        });
    }
    [self.bitrateHandler sendBufferSize:(NSUInteger)(debugInfo.currentBandwidth * 8)];
}

- (void)socketBufferStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveBuffferState)status {
    // remove original buffer changed code.
}

- (void)socketRTMPError:(id<LFStreamSocket>)socket errorCode:(NSInteger)errorCode message:(NSString *)message {
    if (self.delegate && [self.delegate respondsToSelector:@selector(liveSession:errorCode:message:)]) {
        [self.delegate liveSession:self errorCode:errorCode message:message];
    }
}

- (void)socket:(id<LFStreamSocket>)socket rtmpCommandLog:(NSString *)log {
    if ([self.delegate respondsToSelector:@selector(liveSession:message:)]) {
        [self.delegate liveSession:self message:log];
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

- (void)setAdaptiveBitrate:(BOOL)adaptiveBitrate {
    _adaptiveBitrate = adaptiveBitrate;
    if (adaptiveBitrate) {
        [self setupBitrateHandleCallback];
    }
}

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
    if (self.relativeTimestamps == 0) {
        self.relativeTimestamps = captureTimestamp;
    }
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

- (void)setVideoPlaceholder:(UIImage *)image {
    CGSize videoSize = _videoConfiguration.videoSize;
    UIImage *resizeImage = [image scaledToSize:videoSize];
    _backgroundPlaceholder = [self getPixelBufferFromCGImage:resizeImage.CGImage];
}

- (CVPixelBufferRef)getPixelBufferFromCGImage:(CGImageRef)image {
    CVPixelBufferRef pixelBuffer;
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    size_t bytePerRow = CGImageGetBytesPerRow(image);
    size_t bitsPerComponent = CGImageGetBitsPerComponent(image);
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
    
    OSType pixelFormatType = kCVPixelFormatType_32BGRA;
    
    NSDictionary *pixelAttributes =
    @{(__bridge NSString *)kCVPixelBufferCGImageCompatibilityKey : @(YES),
      (__bridge NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey : @(YES),
      (__bridge NSString *)kCVPixelBufferWidthKey : @(width),
      (__bridge NSString *)kCVPixelBufferHeightKey : @(height)};
    
    CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormatType, (__bridge CFDictionaryRef)pixelAttributes, &pixelBuffer);
    if (ret != kCVReturnSuccess) {
        
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *baseData = CVPixelBufferGetBaseAddress(pixelBuffer);
    CGContextRef context = CGBitmapContextCreate(baseData, width, height, bitsPerComponent, bytePerRow, colorSpace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer;
}

@end
