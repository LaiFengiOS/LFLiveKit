//
//  RKAudioMixSource.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/10/2.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKAudioMixSource.h"
#import <AVFoundation/AVFoundation.h>

@implementation RKAudioURLMixSrc {
    NSMutableData *_soundData;
    NSUInteger _mixedSize;
}

- (instancetype)initWithURL:(nonnull NSURL *)url {
    if (self = [super init]) {
        _soundURL = url;
        [self prepareSound];
    }
    return self;
}

- (void)prepareSound {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.soundURL options:nil];
    NSError *error = nil;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:asset error:&error];
    if (error) {
        NSLog(@"%@", error);
        return;
    }
    NSDictionary *outputSettings = @{AVFormatIDKey: @(kAudioFormatLinearPCM),
                                     AVSampleRateKey: @44100,
                                     AVNumberOfChannelsKey: @2,
                                     AVLinearPCMBitDepthKey: @16,
                                     AVLinearPCMIsNonInterleaved: @NO,
                                     AVLinearPCMIsFloatKey: @NO,
                                     AVLinearPCMIsBigEndianKey: @NO};
    
    AVAssetReaderOutput *output = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:asset.tracks audioSettings:outputSettings];
    if (![assetReader canAddOutput:output]) {
        NSLog(@"Failed to add output to reader");
        return;
    }
    [assetReader addOutput: output];
    [assetReader startReading];
    
    _mixedSize = 0;
    _soundData = [NSMutableData data];
    
    CMSampleBufferRef nextBuffer = NULL;
    while ((nextBuffer = [output copyNextSampleBuffer]) != NULL) {
        AudioBufferList audioBufferList;
        CMBlockBufferRef blockBuffer;
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(nextBuffer,
                                                                nil,
                                                                &audioBufferList,
                                                                sizeof(audioBufferList),
                                                                nil,
                                                                nil,
                                                                0,
                                                                &blockBuffer);
        
        AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
        [_soundData appendBytes:audioBuffer.mData length:audioBuffer.mDataByteSize];
        CFRelease(nextBuffer);
        CFRelease(blockBuffer);
    }
    [assetReader cancelReading];
}

- (void)reset {
    _mixedSize = 0;
}

- (BOOL)isFinished {
    return _mixedSize == _soundData.length && !_repeated;
}

- (BOOL)hasNext {
    return !self.isFinished;
}

- (short)next {
    if (self.isFinished) {
        return 0;
    }
    short s;
    const char *soundBytes = _soundData.bytes;
    if (self.mixingChannels == 2) {
        s = (short)(((soundBytes[_mixedSize + 1] & 0xFF) << 8) | (soundBytes[_mixedSize] & 0xFF));
        _mixedSize += 2;
    } else {
        short a = (short)(((soundBytes[_mixedSize + 1] & 0xFF) << 8) | (soundBytes[_mixedSize] & 0xFF));
        short b = (short)(((soundBytes[_mixedSize + 3] & 0xFF) << 8) | (soundBytes[_mixedSize + 2] & 0xFF));
        
        s = (a + b) / 2;// - a * b / 65536.0;

        _mixedSize += 2 * 2;
    }
    if (_mixedSize >= _soundData.length && _repeated) {
        [self reset];
    }
    return s;
}

@end


@implementation RKAudioDataMixSrc {
    NSMutableArray<NSData *> *_dataList;
    NSUInteger _mixingDataIndex;
}

- (instancetype)init {
    if (self = [super init]) {
        _dataList = [NSMutableArray array];
        _mixingDataIndex = 0;
    }
    return self;
}

- (void)pushData:(NSData *)data {
    if (data.length >= 2) {
        [_dataList addObject:data];
    }
}

- (NSData *)popData {
    _mixingDataIndex = 0;
    NSData *returnedData = _dataList.firstObject;
    [_dataList removeObjectAtIndex:0];
    return returnedData;
}

- (BOOL)isEmpty {
    return (_dataList.count == 0 || _dataList[0].length == 0);
}

- (BOOL)hasNext {
    return !self.isEmpty;
}

- (short)next {
    if (_dataList.count == 0 || _dataList[0].length < 2) {
        return 0;
    }
    const char *sideBytes = _dataList[0].bytes;
    short s = (short)(((sideBytes[_mixingDataIndex + 1] & 0xFF) << 8) | (sideBytes[_mixingDataIndex] & 0xFF));
    _mixingDataIndex += 2;
    if (_mixingDataIndex >= _dataList[0].length) {
        [_dataList removeObjectAtIndex:0];
        _mixingDataIndex = 0;
    }
    return s;
}

- (SInt16)nextFrame {
    if (_dataList.count == 0 || _dataList[0].length < 2) {
        return 0;
    }
    SInt16 s = *((SInt16*)_dataList[0].bytes);
    _mixingDataIndex += 2;
    if (_mixingDataIndex >= _dataList[0].length) {
        [_dataList removeObjectAtIndex:0];
        _mixingDataIndex = 0;
    }
    return s;
}

- (void)readBytes:(void *)dst length:(NSUInteger)length {
    NSUInteger readLength = 0;
    while (readLength < length && !self.isEmpty) {
        const void *src = _dataList[0].bytes;
        src += _mixingDataIndex;
        size_t size = MIN(_dataList[0].length - _mixingDataIndex, length - readLength);
        memcpy(dst, src, size);
        _mixingDataIndex += size;
        if (_mixingDataIndex >= _dataList[0].length) {
            [_dataList removeObjectAtIndex:0];
            _mixingDataIndex = 0;
        }
        readLength += size;
        dst += size;
    }
}

@end
