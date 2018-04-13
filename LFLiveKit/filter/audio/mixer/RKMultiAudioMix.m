//
//  RKMultiAudioMix.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/10/2.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKMultiAudioMix.h"

@implementation RKMultiAudioMix

+ (void)mixParts:(NSArray<RKAudioMixPart *> *)parts onAudio:(AudioBufferList)buffers {
    for (int i = 0; i < buffers.mNumberBuffers; i++) {
        AudioBuffer buf = buffers.mBuffers[i];
        char *audioBytes = buf.mData;
        for (int j = 0; j < buf.mDataByteSize; j += 2) {
            float totalW = 1;
            for (RKAudioMixPart *part in parts) {
                if (part.source.hasNext) {
                    totalW += part.weight;
                }
            }
            short a = (short)(((audioBytes[j + 1] & 0xFF) << 8) | (audioBytes[j] & 0xFF)) * (1.0 / totalW);
            for (RKAudioMixPart *part in parts) {
                if (part.source.hasNext) {
                    short b = [part.source next] * (part.weight / totalW);
                    a += b;
                }
            }
            audioBytes[j] = a & 0xFF;
            audioBytes[j + 1] = (a >> 8) & 0xFF;
        }
    }
}

@end


@implementation RKAudioMixPart

@end

