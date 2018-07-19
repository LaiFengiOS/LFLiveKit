//
//  RKSampleBuffer.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol RKSampleBuffer <NSObject>

@property (nonatomic, readonly) NSUInteger bufferedSampleCount;
@property (nonatomic, readonly) NSUInteger bufferedDataSize;
@property (nonatomic, readonly) NSTimeInterval estimatedBufferedSeconds;
@property (nonatomic, readonly) BOOL isEmpty;

- (void)pushSample:(CMSampleBufferRef)sample;

@end

@class RKVideoSample;

@interface RKVideoSampleBuffer : NSObject <RKSampleBuffer>

@property (nonatomic, readonly) NSUInteger esimatedVideoFrameRate;

- (CVPixelBufferRef)readFrame;

- (RKVideoSample *)readSample;

@end

@class RKAudioSample;

@interface RKAudioSampleBuffer : NSObject <RKSampleBuffer>

@property (nonatomic, readonly) AudioStreamBasicDescription audioFormat;

@property (nonatomic, readonly) NSTimeInterval firstFrameTimestamp;

- (RKAudioSample *)firstSample;

- (RKAudioSample *)readSample;

- (NSData *)readDataWithLength:(NSUInteger)length readSampleBlock:(void(^)(RKAudioSample *next, BOOL *stop))sampleBlock;

- (short)readFrame;

- (void)readBytes:(char *)bytes length:(NSUInteger)length;

- (NSData *)readToTimestamp:(NSTimeInterval)timestamp;

@end


@interface RKVideoSample : NSObject

@property (nonatomic, readonly) CVPixelBufferRef pixelBuffer;

@property (nonatomic, readonly) NSTimeInterval timestamp;

@end

@interface RKAudioSample : NSObject

@property (strong, nonatomic, readonly) NSData *data;

@property (nonatomic, readonly) NSUInteger numberOfFrames;

@property (nonatomic, readonly) CMTime timestamp;
@property (nonatomic, readonly) CMTime duration;

@property (nonatomic, readonly) BOOL isReading;

// 10 ms based
@property (nonatomic, readonly) NSUInteger startTimeBase;
@property (nonatomic, readonly) NSUInteger endTimeBase;

@end
