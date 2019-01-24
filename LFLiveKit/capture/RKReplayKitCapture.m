//
//  RKReplayKitCapture.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKReplayKitCapture.h"
#import "RKAudioMixSource.h"
#import "RKReplayKitGLContext.h"
#import <ReplayKit/ReplayKit.h>

@interface RKReplayKitCapture ()

@property (nonatomic) AudioStreamBasicDescription appAudioFormat;

@property (nonatomic) AudioStreamBasicDescription micAudioFormat;

@property (strong, nonatomic) RKAudioDataMixSrc *micDataSrc;

@property (strong, nonatomic) RKReplayKitGLContext *glContext;

@property (nonatomic) CFTimeInterval lastVideoTime;

@property (nonatomic) CFTimeInterval lastAppAudioTime;

@property (strong, nonatomic) dispatch_queue_t slienceAudioQueue;

@property (assign, nonatomic, readonly) CGSize targetCanvasSize;

@end

@implementation RKReplayKitCapture

+ (AudioStreamBasicDescription)defaultAudioFormat {
    static AudioStreamBasicDescription format = {0};
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        format.mSampleRate = 44100;
        format.mFormatID = kAudioFormatLinearPCM;
        format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        format.mChannelsPerFrame = 1;
        format.mFramesPerPacket = 1;
        format.mBitsPerChannel = 16;
        format.mBytesPerFrame = format.mBitsPerChannel / 8 * format.mChannelsPerFrame;
        format.mBytesPerPacket = format.mBytesPerFrame * format.mFramesPerPacket;
    });
    return format;
}

- (instancetype)init {
    if (self = [super init]) {
        _targetCanvasSize = CGSizeMake(720, 1280);
        _micDataSrc = [[RKAudioDataMixSrc alloc] init];
        _slienceAudioQueue = dispatch_queue_create("livekit.replaykitcapture.sliencequeue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)pushVideoSample:(CMSampleBufferRef)sample {
    if (!_videoConfiguration) {
        _videoConfiguration = [LFLiveVideoConfiguration defaultConfigurationFromSampleBuffer:sample];
        
        if (@available(iOS 11.1, *)) {
            CFNumberRef orientationAttachment = CMGetAttachment(sample, (__bridge CFStringRef)RPVideoSampleOrientationKey, NULL);
            CGImagePropertyOrientation orientation = [(__bridge NSNumber*)orientationAttachment intValue];
            _videoConfiguration.videoSize = orientation <= kCGImagePropertyOrientationDownMirrored ? self.targetCanvasSize : CGSizeMake(self.targetCanvasSize.height, self.targetCanvasSize.width);
        }
        _glContext = [[RKReplayKitGLContext alloc] initWithCanvasSize:_videoConfiguration.videoSize];
    }
    
    [self processVideo:sample];
    
    _lastVideoTime = CACurrentMediaTime();
    [self checkAudio];
}

- (void)processVideo:(CMSampleBufferRef)sample {
    [self handleVideoOrientation:sample];
    [_glContext processPixelBuffer:CMSampleBufferGetImageBuffer(sample)];
    [_glContext render];
    [_delegate replayKitCapture:self didCaptureVideo:_glContext.outputPixelBuffer];
}

- (void)handleVideoOrientation:(CMSampleBufferRef)sample {
    if (@available(iOS 11.1, *)) {
        CFNumberRef orientationAttachment = CMGetAttachment(sample, (__bridge CFStringRef)RPVideoSampleOrientationKey, NULL);
        CGImagePropertyOrientation orientation = [(__bridge NSNumber*)orientationAttachment intValue];
        
        CGSize canvasSize = orientation <= kCGImagePropertyOrientationDownMirrored ? self.targetCanvasSize : CGSizeMake(self.targetCanvasSize.height, self.targetCanvasSize.width);
        _glContext.canvasSize = canvasSize;
        
        if (orientation == kCGImagePropertyOrientationUp) {
            [_glContext setRotation:90];
        } else if (orientation == kCGImagePropertyOrientationDown) {
            [_glContext setRotation:-90];
        } else if (orientation == kCGImagePropertyOrientationRight) {
            [_glContext setRotation:180];
        } else {
            [_glContext setRotation:0];
        }
    }
}

- (void)pushAppAudioSample:(CMSampleBufferRef)sample {
    _lastAppAudioTime = CACurrentMediaTime();
    
    _appAudioFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sample));
    
    if (!_audioConfiguration) {
        _audioConfiguration = [LFLiveAudioConfiguration defaultConfigurationFromFormat:_appAudioFormat];
    }
    
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer;
    OSStatus status =
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample,
                                                            NULL,
                                                            &audioBufferList,
                                                            sizeof(audioBufferList),
                                                            NULL,
                                                            NULL,
                                                            0,
                                                            &blockBuffer);
    if (status != noErr) {
        NSLog(@"app audio sample error = %d", (int)status);
        return;
    }
    for (int i = 0; i < audioBufferList.mNumberBuffers; i++) {
        AudioBuffer audioBuffer = audioBufferList.mBuffers[i];
        NSAssert(audioBuffer.mDataByteSize % 2 == 0, @"data size error");
        NSAssert(audioBuffer.mData != NULL, @"data is null");
        NSAssert(audioBuffer.mNumberChannels == 1, @"channel is not mono");
        [self convertAudioBufferToNativeEndian:audioBuffer fromFormat:_appAudioFormat];
        [self mixMicAudioToAudioBuffer:audioBuffer];
        NSData *data = [NSData dataWithBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
        [_delegate replayKitCapture:self didCaptureAudio:data];
    }
    CFRelease(blockBuffer);
}

- (void)pushMicAudioSample:(CMSampleBufferRef)sample {
    _micAudioFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sample));
    
    if (!_audioConfiguration) {
        _audioConfiguration = [LFLiveAudioConfiguration defaultConfigurationFromFormat:_micAudioFormat];
    }
    
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer;
    OSStatus status =
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sample,
                                                            NULL,
                                                            &audioBufferList,
                                                            sizeof(audioBufferList),
                                                            NULL,
                                                            NULL,
                                                            0,
                                                            &blockBuffer);
    if (status != noErr) {
        NSLog(@"mic audio sample error = %d", (int)status);
        return;
    }
    for (int i = 0; i < audioBufferList.mNumberBuffers; i++) {
        AudioBuffer audioBuffer = audioBufferList.mBuffers[i];
        NSAssert(audioBuffer.mDataByteSize % 2 == 0, @"data size error");
        NSAssert(audioBuffer.mData != NULL, @"data is null");
        NSAssert(audioBuffer.mNumberChannels == 1, @"channel is not mono");
        [self convertAudioBufferToNativeEndian:audioBuffer fromFormat:_micAudioFormat];
        NSData *data = [NSData dataWithBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
        [_micDataSrc pushData:data];
    }
    CFRelease(blockBuffer);
}

- (void)mixMicAudioToAudioBuffer:(AudioBuffer)audioBuffer {
    char *audioBytes = audioBuffer.mData;
    for (int i = 0; i < audioBuffer.mDataByteSize && _micDataSrc.hasNext; i += 2) {
        short a = (short)(((audioBytes[i + 1] & 0xFF) << 8) | (audioBytes[i] & 0xFF));
        short b = [_micDataSrc next];
        int mixed = (a + b) / 2;
        audioBytes[i] = mixed & 0xFF;
        audioBytes[i + 1] = (mixed >> 8) & 0xFF;
    }
}

- (void)checkAudio {
    if (_lastAppAudioTime == 0) {
        _lastAppAudioTime = _lastVideoTime;
        return;
    }
    
    CFTimeInterval diffInterval = _lastVideoTime - _lastAppAudioTime;
    if (diffInterval >= 1) {
        _lastAppAudioTime = _lastVideoTime;
        __weak typeof(self) wSelf = self;
        dispatch_async(_slienceAudioQueue, ^{
            [wSelf sendSlience];
        });
    }
}

- (void)sendSlience {
    AudioStreamBasicDescription audioFormat = [self.class defaultAudioFormat];
    if (!_audioConfiguration) {
        _audioConfiguration = [LFLiveAudioConfiguration defaultConfigurationFromFormat:audioFormat];
    }
    NSUInteger size = audioFormat.mSampleRate * audioFormat.mBytesPerFrame;   // 0.5 sec
    char *bytes = (char *)malloc(size);
    memset(bytes, 0, size);
    [_micDataSrc readBytes:bytes length:size];
    NSData *data = [NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:YES];
    [_delegate replayKitCapture:self didCaptureAudio:data];
}

- (void)convertAudioBufferToNativeEndian:(AudioBuffer)buffer fromFormat:(AudioStreamBasicDescription)format {
    if (format.mFormatFlags & kAudioFormatFlagIsBigEndian) {
        int i = 0;
        char *ptr = buffer.mData;
        while (i < buffer.mDataByteSize) {
            SInt16 value = CFSwapInt16BigToHost(*((SInt16*)ptr));
            memcpy(ptr, &value, 2);
            i += 2;
            ptr += 2;
        }
    }
}

- (void)convertDataToNativeEndian:(NSMutableData *)data fromFormat:(AudioStreamBasicDescription)format {
    if (format.mFormatFlags & kAudioFormatFlagIsBigEndian) {
        const void *ptr = data.bytes;
        for (int i = 0; i < data.length; i += 2) {
            SInt16 endian = CFSwapInt16BigToHost(*((SInt16*)ptr));
            [data replaceBytesInRange:NSMakeRange(i, 2) withBytes:&endian];
            ptr += 2;
        }
    }
}

@end
