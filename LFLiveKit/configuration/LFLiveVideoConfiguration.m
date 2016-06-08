//
//  LFLiveVideoConfiguration.m
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/1.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFLiveVideoConfiguration.h"
#import <AVFoundation/AVFoundation.h>

@implementation LFLiveVideoConfiguration

#pragma mark -- LifeCycle
+ (instancetype)defaultConfiguration{
    LFLiveVideoConfiguration *configuration = [LFLiveVideoConfiguration defaultConfigurationForQuality:LFLiveVideoQuality_Default];
    return configuration;
}

+ (instancetype)defaultConfigurationForQuality:(LFLiveVideoQuality)videoQuality{
    LFLiveVideoConfiguration *configuration = [LFLiveVideoConfiguration defaultConfigurationForQuality:videoQuality orientation:UIInterfaceOrientationPortrait];
    return configuration;
}

+ (instancetype)defaultConfigurationForQuality:(LFLiveVideoQuality)videoQuality orientation:(UIInterfaceOrientation)orientation{
    LFLiveVideoConfiguration *configuration = [LFLiveVideoConfiguration new];
    switch (videoQuality) {
            case LFLiveVideoQuality_Low1:
        {
            configuration.sessionPreset = LFCaptureSessionPreset360x640;
            configuration.videoFrameRate = 15;
            configuration.videoMaxFrameRate = 15;
            configuration.videoMinFrameRate = 10;
            configuration.videoBitRate = 500 * 1024;
            configuration.videoMaxBitRate = 600 * 1024;
            configuration.videoMinBitRate = 250 * 1024;
        }
            break;
            case LFLiveVideoQuality_Low2:
        {
            configuration.sessionPreset = LFCaptureSessionPreset360x640;
            configuration.videoFrameRate = 24;
            configuration.videoMaxFrameRate = 24;
            configuration.videoMinFrameRate = 12;
            configuration.videoBitRate = 800 * 1024;
            configuration.videoMaxBitRate = 900 * 1024;
            configuration.videoMinBitRate = 500 * 1024;
        }
            break;
            case LFLiveVideoQuality_Low3:
        {
            configuration.sessionPreset = LFCaptureSessionPreset360x640;
            configuration.videoFrameRate = 30;
            configuration.videoMaxFrameRate = 30;
            configuration.videoMinFrameRate = 15;
            configuration.videoBitRate = 800 * 1024;
            configuration.videoMaxBitRate = 900 * 1024;
            configuration.videoMinBitRate = 500 * 1024;
        }
            break;
            case LFLiveVideoQuality_Medium1:
        {
            configuration.sessionPreset = LFCaptureSessionPreset540x960;
            configuration.videoFrameRate = 15;
            configuration.videoMaxFrameRate = 15;
            configuration.videoMinFrameRate = 10;
            configuration.videoBitRate = 800 * 1024;
            configuration.videoMaxBitRate = 900 * 1024;
            configuration.videoMinBitRate = 500 * 1024;
        }
            break;
            case LFLiveVideoQuality_Medium2:
        {
            configuration.sessionPreset = LFCaptureSessionPreset540x960;
            configuration.videoFrameRate = 24;
            configuration.videoMaxFrameRate = 24;
            configuration.videoMinFrameRate = 12;
            configuration.videoBitRate = 800 * 1024;
            configuration.videoMaxBitRate = 900 * 1024;
            configuration.videoMinBitRate = 500 * 1024;
        }
            break;
            case LFLiveVideoQuality_Medium3:
        {
            configuration.sessionPreset = LFCaptureSessionPreset540x960;
            configuration.videoFrameRate = 30;
            configuration.videoMaxFrameRate = 30;
            configuration.videoMinFrameRate = 15;
            configuration.videoBitRate = 1000 * 1024;
            configuration.videoMaxBitRate = 1200 * 1024;
            configuration.videoMinBitRate = 500 * 1024;
        }
            break;
            case LFLiveVideoQuality_High1:
        {
            configuration.sessionPreset = LFCaptureSessionPreset720x1280;
            configuration.videoFrameRate = 15;
            configuration.videoMaxFrameRate = 15;
            configuration.videoMinFrameRate = 10;
            configuration.videoBitRate = 1000 * 1024;
            configuration.videoMaxBitRate = 1200 * 1024;
            configuration.videoMinBitRate = 500 * 1024;
        }
            break;
            case LFLiveVideoQuality_High2:
        {
            configuration.sessionPreset = LFCaptureSessionPreset720x1280;
            configuration.videoFrameRate = 24;
            configuration.videoMaxFrameRate = 24;
            configuration.videoMinFrameRate = 12;
            configuration.videoBitRate = 1200 * 1024;
            configuration.videoMaxBitRate = 1300 * 1024;
            configuration.videoMinBitRate = 800 * 1024;
        }
            break;
            case LFLiveVideoQuality_High3:
        {
            configuration.sessionPreset = LFCaptureSessionPreset720x1280;
            configuration.videoFrameRate = 30;
            configuration.videoMaxFrameRate = 30;
            configuration.videoMinFrameRate = 15;
            configuration.videoBitRate = 1200 * 1024;
            configuration.videoMaxBitRate = 1300 * 1024;
            configuration.videoMinBitRate = 500 * 1024;
        }
            break;
        default:
            break;
    }
    configuration.sessionPreset = [configuration supportSessionPreset:configuration.sessionPreset];
    configuration.videoMaxKeyframeInterval = configuration.videoFrameRate*2;
    configuration.orientation = orientation;
    if(orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown){
        configuration.videoSize = CGSizeMake(368, 640);
    }else{
        configuration.videoSize = CGSizeMake(640, 368);
    }
    return configuration;
}

#pragma mark -- Setter Getter
- (NSString*)avSessionPreset{
    NSString *avSessionPreset = nil;
    switch (self.sessionPreset) {
            case LFCaptureSessionPreset360x640:
        {
            avSessionPreset = AVCaptureSessionPreset640x480;
        }
            break;
            case LFCaptureSessionPreset540x960:
        {
            avSessionPreset = AVCaptureSessionPresetiFrame960x540;
        }
            break;
            case LFCaptureSessionPreset720x1280:
        {
            avSessionPreset = AVCaptureSessionPreset1280x720;
        }
            break;
        default:{
            avSessionPreset = AVCaptureSessionPreset640x480;
        }
            break;
    }
    return avSessionPreset;
}

- (void)setVideoMaxBitRate:(NSUInteger)videoMaxBitRate{
    if(videoMaxBitRate <= _videoBitRate) return;
    _videoMaxBitRate = videoMaxBitRate;
}

- (void)setVideoMinBitRate:(NSUInteger)videoMinBitRate{
    if(videoMinBitRate >= _videoBitRate) return;
    _videoMinBitRate = videoMinBitRate;
}

- (void)setVideoMaxFrameRate:(NSUInteger)videoMaxFrameRate{
    if(videoMaxFrameRate <= _videoFrameRate) return;
    _videoMaxFrameRate = videoMaxFrameRate;
}

- (void)setVideoMinFrameRate:(NSUInteger)videoMinFrameRate{
    if(videoMinFrameRate >= _videoFrameRate) return;
    _videoMinFrameRate = videoMinFrameRate;
}


#pragma mark -- Custom Method
- (LFLiveVideoSessionPreset)supportSessionPreset:(LFLiveVideoSessionPreset)sessionPreset{
    NSString *avSessionPreset = [self avSessionPreset];
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    if(![session canSetSessionPreset:avSessionPreset]){
        if(sessionPreset == LFCaptureSessionPreset720x1280){
            sessionPreset = LFCaptureSessionPreset540x960;
            if(![session canSetSessionPreset:avSessionPreset]){
                sessionPreset = LFCaptureSessionPreset360x640;
            }
        }else if(sessionPreset == LFCaptureSessionPreset540x960){
            sessionPreset = LFCaptureSessionPreset360x640;
        }
    }
    return sessionPreset;
}

- (BOOL)isClipVideo{
    return self.sessionPreset == LFCaptureSessionPreset360x640 ? YES : NO;
}

#pragma mark -- encoder
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:[NSValue valueWithCGSize:self.videoSize] forKey:@"videoSize"];
    [aCoder encodeObject:@(self.videoFrameRate) forKey:@"videoFrameRate"];
    [aCoder encodeObject:@(self.videoMaxKeyframeInterval) forKey:@"videoMaxKeyframeInterval"];
    [aCoder encodeObject:@(self.videoBitRate) forKey:@"videoBitRate"];
    [aCoder encodeObject:@(self.sessionPreset) forKey:@"sessionPreset"];
    [aCoder encodeObject:@(self.orientation) forKey:@"orientation"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    _videoSize = [[aDecoder decodeObjectForKey:@"videoSize"] CGSizeValue];
    _videoFrameRate = [[aDecoder decodeObjectForKey:@"videoFrameRate"] unsignedIntegerValue];
    _videoMaxKeyframeInterval = [[aDecoder decodeObjectForKey:@"videoMaxKeyframeInterval"] unsignedIntegerValue];
    _videoBitRate = [[aDecoder decodeObjectForKey:@"videoBitRate"] unsignedIntegerValue];
    _sessionPreset = [[aDecoder decodeObjectForKey:@"sessionPreset"] unsignedIntegerValue];
    _orientation = [[aDecoder decodeObjectForKey:@"orientation"] unsignedIntegerValue];
    return self;
}

- (NSUInteger)hash {
    NSUInteger hash = 0;
    NSArray *values = @[[NSValue valueWithCGSize:self.videoSize],
                        @(self.videoFrameRate),
                        @(self.videoMaxFrameRate),
                        @(self.videoMinFrameRate),
                        @(self.videoMaxKeyframeInterval),
                        @(self.videoBitRate),
                        @(self.videoMaxBitRate),
                        @(self.videoMinBitRate),
                        @(self.isClipVideo),
                        self.avSessionPreset,
                        @(self.sessionPreset),
                        @(self.orientation),];
    
    for (NSObject *value in values) {
        hash ^= value.hash;
    }
    return hash;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        LFLiveVideoConfiguration *object = other;
        return CGSizeEqualToSize(object.videoSize, self.videoSize)  &&
        object.videoFrameRate == self.videoFrameRate &&
        object.videoMaxFrameRate == self.videoMaxFrameRate &&
        object.videoMinFrameRate == self.videoMinFrameRate &&
        object.videoMaxKeyframeInterval == self.videoMaxKeyframeInterval &&
        object.videoBitRate == self.videoBitRate &&
        object.videoMaxBitRate == self.videoMaxBitRate &&
        object.videoMinBitRate == self.videoMinBitRate &&
        object.isClipVideo == self.isClipVideo &&
        [object.avSessionPreset isEqualToString:self.avSessionPreset] &&
        object.sessionPreset == self.sessionPreset &&
        object.orientation == self.orientation;
    }
}

- (id)copyWithZone:(nullable NSZone *)zone{
    LFLiveVideoConfiguration *other = [self.class defaultConfiguration];
    return other;
}

- (NSString *)description{
    NSMutableString *desc = @"".mutableCopy;
    [desc appendFormat:@"<LFLiveVideoConfiguration: %p>",self];
    [desc appendFormat:@" videoSize:%@",NSStringFromCGSize(self.videoSize)];
    [desc appendFormat:@" videoFrameRate:%zi",self.videoFrameRate];
    [desc appendFormat:@" videoMaxFrameRate:%zi",self.videoMaxFrameRate];
    [desc appendFormat:@" videoMinFrameRate:%zi",self.videoMinFrameRate];
    [desc appendFormat:@" videoMaxKeyframeInterval:%zi",self.videoMaxKeyframeInterval];
    [desc appendFormat:@" videoBitRate:%zi",self.videoBitRate];
    [desc appendFormat:@" videoMaxBitRate:%zi",self.videoMaxBitRate];
    [desc appendFormat:@" videoMinBitRate:%zi",self.videoMinBitRate];
    [desc appendFormat:@" isClipVideo:%zi",self.isClipVideo];
    [desc appendFormat:@" avSessionPreset:%@",self.avSessionPreset];
    [desc appendFormat:@" sessionPreset:%zi",self.sessionPreset];
    [desc appendFormat:@" orientation:%zi",self.orientation];
    return desc;
}

@end
