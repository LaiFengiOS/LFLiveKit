//
//  RKSampleBuffer.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/19.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "RKSampleBuffer.h"
#import <QuartzCore/QuartzCore.h>
#import "RKLinkedList.h"

@implementation RKVideoSample

- (instancetype)initWithImageBuffer:(CVImageBufferRef)buffer {
    if (self = [super init]) {
        _pixelBuffer = CVPixelBufferRetain(buffer);
        _timestamp = CACurrentMediaTime();
    }
    return self;
}

- (void)dealloc {
    CVPixelBufferRelease(_pixelBuffer);
}

@end

@implementation RKAudioSample

- (instancetype)initWithData:(NSData *)data start:(NSUInteger)start end:(NSUInteger)end {
    if (self = [super init]) {
        _data = data;
        _startTimeBase = start;
        _endTimeBase = end;
    }
    return self;
}

- (instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (self = [super init]) {
        _timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        _duration = CMSampleBufferGetDuration(sampleBuffer);
        _numberOfFrames = CMSampleBufferGetNumSamples(sampleBuffer);
        
        AudioBufferList audioBufferList;
        CMBlockBufferRef blockBuffer;
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                NULL,
                                                                &audioBufferList,
                                                                sizeof(audioBufferList),
                                                                NULL,
                                                                NULL,
                                                                0,
                                                                &blockBuffer);
        if (audioBufferList.mNumberBuffers > 1) {
            NSMutableData *audioData = [NSMutableData new];
            for (int i = 0; i < audioBufferList.mNumberBuffers; i++) {
                AudioBuffer audioBuffer = audioBufferList.mBuffers[i];
                [audioData appendBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
            }
            _data = audioData;
        } else if (audioBufferList.mNumberBuffers == 1) {
            AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
            _data = [NSData dataWithBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
        }
        CFRelease(blockBuffer);
    }
    return self;
}

- (void)setReading:(BOOL)reading {
    _isReading = reading;
}

@end


@implementation RKVideoSampleBuffer {
    RKLinkedList *_bufferList;
}
@synthesize bufferedDataSize = _bufferedSize;
@synthesize esimatedVideoFrameRate = _frameRate;

- (instancetype)init {
    if (self = [super init]) {
        _frameRate = 30;
    }
    return self;
}

- (void)setupBuffer {
    _bufferList = [[RKLinkedList alloc] init];
    _frameRate = 30;
    __weak typeof(self) wSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _frameRate = wSelf.bufferedSampleCount;
    });
}

- (void)pushSample:(CMSampleBufferRef)sample {
    if (!_bufferList) {
        [self setupBuffer];
    }
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sample);
    _bufferedSize += CVPixelBufferGetDataSize(imageBuffer);
    
    RKVideoSample *node = [[RKVideoSample alloc] initWithImageBuffer:imageBuffer];
    [_bufferList pushTail:node];
}

- (NSUInteger)bufferedSampleCount {
    return _bufferList.length;
}

- (NSTimeInterval)estimatedBufferedSeconds {
    return (double)self.bufferedSampleCount / self.esimatedVideoFrameRate;
}

- (BOOL)isEmpty {
    return _bufferList.length == 0;
}

- (CVPixelBufferRef)readFrame {
    RKVideoSample *node = [_bufferList popHead];
    return node.pixelBuffer;
}

- (RKVideoSample *)readSample {
    return [_bufferList popHead];
}

@end


@implementation RKAudioSampleBuffer {
    RKLinkedList *_bufferList;
    NSUInteger _bufferIndex;
}
@synthesize bufferedDataSize = _bufferedSize;

- (void)setupBufferWithSample:(CMSampleBufferRef)sample {
    _bufferList = [[RKLinkedList alloc] init];
    _bufferIndex = 0;
    CMAudioFormatDescriptionRef desc = CMSampleBufferGetFormatDescription(sample);
    _audioFormat = *CMAudioFormatDescriptionGetStreamBasicDescription(desc);
}

- (void)pushSample:(CMSampleBufferRef)sample {
    if (!_bufferList) {
        [self setupBufferWithSample:sample];
    }
    
    
    //    NSUInteger sampleCount = audioData.length / 2;
    //    NSUInteger endTimeBase = CACurrentMediaTime() * 100;
    //    NSUInteger startTimeBase = endTimeBase - ceil(sampleCount / 441.0);
    //    RKAudioSample *audioSample = [[RKAudioSample alloc] initWithData:audioData start:startTimeBase end:endTimeBase];
    
    RKAudioSample *audioSample = [[RKAudioSample alloc] initWithSampleBuffer:sample];
    [_bufferList pushTail:audioSample];
    _bufferedSize += audioSample.data.length;
}

- (NSUInteger)bufferedSampleCount {
    return _bufferedSize / _audioFormat.mBytesPerFrame;
}

- (NSTimeInterval)estimatedBufferedSeconds {
    return self.bufferedSampleCount / _audioFormat.mSampleRate;
}

- (BOOL)isEmpty {
    return _bufferedSize == 0;
}

- (RKAudioSample *)firstSample {
    return _bufferList.head;
}

- (RKAudioSample *)readSample {
    RKAudioSample *sample = [_bufferList popHead];
    _bufferedSize -= sample.data.length;
    _bufferIndex = 0;
    return sample;
}

- (NSData *)readDataWithLength:(NSUInteger)length readSampleBlock:(void(^)(RKAudioSample *next, BOOL *stop))sampleBlock {
    if (!_bufferList.head) {
        return nil;
    }
    NSData *data = nil;
    RKAudioSample *sample = _bufferList.head;
    if (_bufferIndex == 0 && length == sample.data.length) {
        [_bufferList popHead];
        data = sample.data;
    } else {
        NSMutableData *mData = [NSMutableData dataWithCapacity:length];
        NSUInteger filledLength = 0;
        while (sample != nil) {
            const void *ptr = sample.data.bytes + _bufferIndex;
            NSUInteger readLength = MIN(sample.data.length - _bufferIndex, length - filledLength);
            [mData appendBytes:ptr length:readLength];
            filledLength += readLength;
            _bufferIndex += readLength;
            if (_bufferIndex >= sample.data.length) {
                [_bufferList popHead];
                _bufferIndex = 0;
                sample = _bufferList.head;
            }
            if (filledLength == length) {
                break;
            }
            if (sample && !sample.isReading) {
                if (sampleBlock) {
                    BOOL stop;
                    sampleBlock(sample, &stop);
                    if (stop) {
                        break;
                    }
                }
                sample.reading = YES;
            }
        }
        if (filledLength < length) {
            [mData appendData:[NSMutableData dataWithLength:length - filledLength]];
        }
        data = mData;
    }
    _bufferedSize -= data.length;
    
    return data;
}

- (short)readFrame {
    if (!_bufferList.head) {
        return 0;
    }
    RKAudioSample *sample = _bufferList.head;
    const char *bytes = sample.data.bytes;
    short s = (short)(((bytes[_bufferIndex + 1] & 0xFF) << 8) | (bytes[_bufferIndex] & 0xFF));
    _bufferedSize -= 2;
    _bufferIndex += 2;
    if (_bufferIndex >= sample.data.length) {
        [_bufferList popHead];
        _bufferIndex = 0;
    }
    return s;
}

- (void)readBytes:(char *)bytes length:(NSUInteger)length {
    if (!_bufferList.head) {
        return;
    }
    RKAudioSample *sample = _bufferList.head;
    const char *dataBytes = sample.data.bytes;
    for (int i = 0; i < length; i++) {
        bytes[i] = dataBytes[_bufferIndex];
        _bufferedSize--;
        _bufferIndex++;
        if (_bufferIndex >= sample.data.length) {
            [_bufferList popHead];
            _bufferIndex = 0;
        }
        if (!_bufferList.head) {
            break;
        }
    }
}

- (NSData *)readToTimestamp:(NSTimeInterval)timestamp {
    // base on 10 ms
    NSUInteger timeBase = timestamp * 100;
    NSMutableData *data = [NSMutableData new];
    RKAudioSample *sample = _bufferList.head;
    while (sample != nil && sample.startTimeBase < timeBase) {
        if (sample.endTimeBase <= timeBase) {
            if (_bufferIndex == 0) {
                [data appendData:sample.data];
            } else {
                const void *ptr = sample.data.bytes + _bufferIndex;
                [data appendBytes:ptr length:sample.data.length - _bufferIndex];
            }
            [_bufferList popHead];
            _bufferIndex = 0;
            sample = _bufferList.head;
        } else {
            // 10 ms = 441 frames
            NSUInteger stopLength = (int)(timeBase - sample.startTimeBase) * 441 * 2;
            NSUInteger readLength = stopLength - _bufferIndex;
            const void *ptr = sample.data.bytes + _bufferIndex;
            [data appendBytes:ptr length:readLength];
            _bufferIndex += readLength;
            if (_bufferIndex >= sample.data.length) {
                [_bufferList popHead];
                _bufferIndex = 0;
            }
            break;
        }
    }
    _bufferedSize -= data.length;
    
    return data;
}

@end
