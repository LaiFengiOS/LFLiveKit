//
//  RKAudioMix.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/9/4.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKAudioMix.h"

@implementation RKAudioDataMix {
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

- (void)process:(AudioBufferList)buffers {
    if (_dataList.count == 0 || _dataList[0].length < 2) {
        return;
    }
    AudioBuffer buf = buffers.mBuffers[0];
    for (int i = 0; i < buf.mDataByteSize; i += 2) {
        char *audioBytes = buf.mData;
        const char *sideBytes = _dataList[0].bytes;
        short a = (short)(((audioBytes[i + 1] & 0xFF) << 8) | (audioBytes[i] & 0xFF));
        short b = (short)(((sideBytes[_mixingDataIndex + 1] & 0xFF) << 8) | (sideBytes[_mixingDataIndex] & 0xFF));
        
        int mixed = (a + b) / 2;
        //int mixed = a + b - a * b / 65536.0;
        audioBytes[i] = mixed & 0xFF;
        audioBytes[i + 1] = (mixed >> 8) & 0xFF;
        
        _mixingDataIndex += 2;
        if (_mixingDataIndex >= _dataList[0].length) {
            [_dataList removeObjectAtIndex:0];
            _mixingDataIndex = 0;
        }
        if (_dataList.count == 0 || _dataList[0].length < 2) {
            break;
        }
    }
}

@end
