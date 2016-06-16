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
#import "LFStreamRtmpSocket.h"
#import "LFStreamTcpSocket.h"
#import "LFLiveStreamInfo.h"

#define LFLiveReportKey @"com.youku.liveSessionReport"

@interface LFLiveSession ()<LFAudioCaptureDelegate,LFVideoCaptureDelegate,LFAudioEncodingDelegate,LFVideoEncodingDelegate,LFStreamSocketDelegate>
{
    dispatch_semaphore_t _lock;
}
///流媒体格式
@property (nonatomic, assign) LFLiveType liveType;
///音频配置
@property (nonatomic, strong) LFLiveAudioConfiguration *audioConfiguration;
///视频配置
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
/// 上报
@property (nonatomic, copy) dispatch_block_t reportBlock;
/// debugInfo
@property (nonatomic, strong) LFLiveDebug *debugInfo;
/// streamInfo
@property (nonatomic, strong) LFLiveStreamInfo *streamInfo;
/// uploading
@property (nonatomic, assign) BOOL uploading;
/// state
@property (nonatomic,assign,readwrite) LFLiveState state;

@end

/**  时间戳 */
#define NOW (CACurrentMediaTime()*1000)
@interface LFLiveSession ()

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) uint64_t currentTimestamp;

@end

@implementation LFLiveSession

#pragma mark -- LifeCycle
- (instancetype)initWithAudioConfiguration:(LFLiveAudioConfiguration *)audioConfiguration videoConfiguration:(LFLiveVideoConfiguration *)videoConfiguration liveType:(LFLiveType)liveType{
    if(!audioConfiguration || !videoConfiguration) @throw [NSException exceptionWithName:@"LFLiveSession init error" reason:@"audioConfiguration or videoConfiguration is nil " userInfo:nil];
    if(self = [super init]){
        _audioConfiguration = audioConfiguration;
        _videoConfiguration = videoConfiguration;
        _liveType = liveType;
        _lock = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)dealloc{
    self.audioCaptureSource.running = NO;
    self.videoCaptureSource.running = NO;
}

#pragma mark -- CustomMethod
- (void)startLive:(LFLiveStreamInfo*)streamInfo{
    if(!streamInfo) return;
    _streamInfo = streamInfo;
    _streamInfo.videoConfiguration = _videoConfiguration;
    _streamInfo.audioConfiguration = _audioConfiguration;
    [self.socket start];
}

- (void)stopLive{
    self.uploading = NO;
    [self.socket stop];
}

#pragma mark -- CaptureDelegate
- (void)captureOutput:(nullable LFAudioCapture*)capture audioBuffer:(AudioBufferList)inBufferList{
    [self.audioEncoder encodeAudioData:inBufferList timeStamp:self.currentTimestamp];
}

- (void)captureOutput:(nullable LFVideoCapture*)capture pixelBuffer:(nullable CVImageBufferRef)pixelBuffer{
    [self.videoEncoder encodeVideoData:pixelBuffer timeStamp:self.currentTimestamp];
}

#pragma mark -- EncoderDelegate
- (void)audioEncoder:(nullable id<LFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame*)frame{
    if(self.uploading) [self.socket sendFrame:frame];//<上传
}

- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame*)frame{
    if(self.uploading) [self.socket sendFrame:frame];//<上传
}

#pragma mark -- LFStreamTcpSocketDelegate
- (void)socketStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveState)status{
    if(status == LFLiveStart){
        if(!self.uploading){
            self.timestamp = 0;
            self.isFirstFrame = YES;
            self.uploading = YES;
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.state = status;
        if(self.delegate && [self.delegate respondsToSelector:@selector(liveSession:liveStateDidChange:)]){
            [self.delegate liveSession:self liveStateDidChange:status];
        }
    });
}

- (void)socketDidError:(nullable id<LFStreamSocket>)socket errorCode:(LFLiveSocketErrorCode)errorCode{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.delegate && [self.delegate respondsToSelector:@selector(liveSession:errorCode:)]){
            [self.delegate liveSession:self errorCode:errorCode];
        }
    });
}

- (void)socketDebug:(nullable id<LFStreamSocket>)socket debugInfo:(nullable LFLiveDebug*)debugInfo{
    self.debugInfo = debugInfo;
    if(self.showDebugInfo){
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.delegate && [self.delegate respondsToSelector:@selector(liveSession:debugInfo:)]){
                [self.delegate liveSession:self debugInfo:debugInfo];
            }
        });
    }
}

- (void)socketBufferStatus:(nullable id<LFStreamSocket>)socket status:(LFLiveBuffferState)status{
    NSUInteger videoBitRate = [_videoEncoder videoBitRate];
    if(status == LFLiveBuffferIncrease){
        if(videoBitRate < _videoConfiguration.videoMaxBitRate){
            videoBitRate = videoBitRate + 50*1024;
            [_videoEncoder setVideoBitRate:videoBitRate];
        }
    }else{
        if(videoBitRate > _videoConfiguration.videoMinBitRate){
            videoBitRate = videoBitRate - 100*1024;
            [_videoEncoder setVideoBitRate:videoBitRate];
        }
    }
}

#pragma mark -- Getter Setter
- (void)setRunning:(BOOL)running{
    if(_running == running) return;
    [self willChangeValueForKey:@"running"];
    _running = running;
    [self didChangeValueForKey:@"running"];
    self.videoCaptureSource.running = _running;
    self.audioCaptureSource.running = _running;
}

- (void)setPreView:(UIView *)preView{
    [self.videoCaptureSource setPreView:preView];
}

- (UIView*)preView{
    return self.videoCaptureSource.preView;
}

- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition{
    [self.videoCaptureSource setCaptureDevicePosition:captureDevicePosition];
}

- (AVCaptureDevicePosition)captureDevicePosition{
    return self.videoCaptureSource.captureDevicePosition;
}

- (void)setBeautyFace:(BOOL)beautyFace{
    [self.videoCaptureSource setBeautyFace:beautyFace];
}

- (BOOL)beautyFace{
    return self.videoCaptureSource.beautyFace;
}

- (void)setMuted:(BOOL)muted{
    [self.audioCaptureSource setMuted:muted];
}

- (BOOL)muted{
    return self.audioCaptureSource.muted;
}

- (LFAudioCapture*)audioCaptureSource{
    if(!_audioCaptureSource){
        _audioCaptureSource = [[LFAudioCapture alloc] initWithAudioConfiguration:_audioConfiguration];
        _audioCaptureSource.delegate = self;
    }
    return _audioCaptureSource;
}

- (LFVideoCapture*)videoCaptureSource{
    if(!_videoCaptureSource){
        _videoCaptureSource = [[LFVideoCapture alloc] initWithVideoConfiguration:_videoConfiguration];
        _videoCaptureSource.delegate = self;
    }
    return _videoCaptureSource;
}

- (id<LFAudioEncoding>)audioEncoder{
    if(!_audioEncoder){
        _audioEncoder = [[LFHardwareAudioEncoder alloc] initWithAudioStreamConfiguration:_audioConfiguration];
        [_audioEncoder setDelegate:self];
    }
    return _audioEncoder;
}

- (id<LFVideoEncoding>)videoEncoder{
    if(!_videoEncoder){
        _videoEncoder = [[LFHardwareVideoEncoder alloc] initWithVideoStreamConfiguration:_videoConfiguration];
        [_videoEncoder setDelegate:self];
    }
    return _videoEncoder;
}

- (id<LFStreamSocket>)socket{
    if(!_socket){
        if(self.liveType == LFLiveRTMP){
            _socket = [[LFStreamRtmpSocket alloc] initWithStream:self.streamInfo];
        }else if(self.liveType == LFLiveFLV){
            _socket = [[LFStreamTcpSocket alloc] initWithStream:self.streamInfo videoSize:self.videoConfiguration.videoSize reconnectInterval:self.reconnectInterval reconnectCount:self.reconnectCount];
        }
        [_socket setDelegate:self];
    }
    return _socket;
}

- (LFLiveStreamInfo*)streamInfo{
    if(!_streamInfo){
        _streamInfo = [[LFLiveStreamInfo alloc] init];
    }
    return _streamInfo;
}

- (uint64_t)currentTimestamp{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if(_isFirstFrame == true) {
        _timestamp = NOW;
        _isFirstFrame = false;
        currentts = 0;
    }
    else {
        currentts = NOW - _timestamp;
    }
    dispatch_semaphore_signal(_lock);
    return currentts;
}

@end
