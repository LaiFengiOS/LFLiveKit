//
//  RKReplayKitCapture.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFLiveAudioConfiguration.h"
#import "LFLiveVideoConfiguration.h"

@protocol RKReplayKitCaptureDelegate;

@interface RKReplayKitCapture : NSObject

@property (weak, nonatomic) id<RKReplayKitCaptureDelegate> delegate;
@property (strong, nonatomic, readonly) LFLiveAudioConfiguration *audioConfiguration;
@property (strong, nonatomic, readonly) LFLiveVideoConfiguration *videoConfiguration;

- (void)pushVideoSample:(CMSampleBufferRef)sample;

- (void)pushAppAudioSample:(CMSampleBufferRef)sample;

- (void)pushMicAudioSample:(CMSampleBufferRef)sample;

@end


@protocol RKReplayKitCaptureDelegate <NSObject>

- (void)replayKitCapture:(RKReplayKitCapture *)capture didCaptureVideo:(CVPixelBufferRef)pixelBuffer;

- (void)replayKitCapture:(RKReplayKitCapture *)capture didCaptureAudio:(NSData *)data;

@end
