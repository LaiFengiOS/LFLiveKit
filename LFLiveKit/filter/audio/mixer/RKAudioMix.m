//
//  RKAudioMix.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/9/4.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKAudioMix.h"
#import "RKDataLinkedList.h"

@implementation RKAudioDataMix {
    RKDataLinkedList *_dataList;
    NSUInteger _mixingDataIndex;
}

- (instancetype)init {
    if (self = [super init]) {
        _dataList = [[RKDataLinkedList alloc] init];
        _mixingDataIndex = 0;
    }
    return self;
}

- (void)pushData:(NSData *)data {
    if (data.length >= 2) {
        [_dataList pushTail:data];
    }
}

- (void)process:(AudioBufferList)buffers {
    if (!_dataList.head) {
        return;
    }
    AudioBuffer buf = buffers.mBuffers[0];
    for (int i = 0; i < buf.mDataByteSize; i += 2) {
        char *audioBytes = buf.mData;
        const char *sideBytes = _dataList.head.bytes;
        short a = (short)(((audioBytes[i + 1] & 0xFF) << 8) | (audioBytes[i] & 0xFF));
        short b = (short)(((sideBytes[_mixingDataIndex + 1] & 0xFF) << 8) | (sideBytes[_mixingDataIndex] & 0xFF));
        
        int mixed = (a + b) / 2;
        audioBytes[i] = mixed & 0xFF;
        audioBytes[i + 1] = (mixed >> 8) & 0xFF;
        
        _mixingDataIndex += 2;
        if (_mixingDataIndex >= _dataList.head.length) {
            [_dataList popHead];
            _mixingDataIndex = 0;
        }
        if (!_dataList.head) {
            break;
        }
    }
}

@end
