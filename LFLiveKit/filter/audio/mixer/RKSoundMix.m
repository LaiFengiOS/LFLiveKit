//
//  RKSoundMix.m
//  LFLiveKit
//
//  Created by Ken Sun on 2017/9/4.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKSoundMix.h"
#import <AVFoundation/AVFoundation.h>

@implementation RKSoundMix {
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
    return _mixedSize == _soundData.length;
}

- (void)process:(AudioBufferList)buffers {
    if (self.isFinished) {
        return;
    }
    const char *soundBytes = _soundData.bytes;
    for (int i = 0; i < buffers.mNumberBuffers; i++) {
        AudioBuffer buf = buffers.mBuffers[i];
        char *audioBytes = buf.mData;
        NSUInteger mixSize = MIN(_soundData.length - _mixedSize, buf.mDataByteSize);
        for (int j = 0; j < mixSize; j++) {
            char byte = audioBytes[j] + soundBytes[_mixedSize + j] / 2;
            if (byte > 127) byte = 127;
            else if (byte <-128) byte = -128;
            audioBytes[j] = byte;
        }
        _mixedSize += mixSize;
    }
}

@end
