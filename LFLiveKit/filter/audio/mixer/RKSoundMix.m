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
    return _mixedSize == _soundData.length && !_repeated;
}


- (void)process:(AudioBufferList)buffers {
    if (self.isFinished) {
        return;
    }
//    const char *soundBytes = _soundData.bytes;
//    for (int i = 0; i < buffers.mNumberBuffers; i++) {
//        AudioBuffer buf = buffers.mBuffers[i];
//        char *audioBytes = buf.mData;
//        NSUInteger mixSize = MIN(_soundData.length - _mixedSize, buf.mDataByteSize);
//        for (int j = 0; j < mixSize; j++) {
//            char byte = audioBytes[j] + soundBytes[_mixedSize + j] / 2;
//            if (byte > 127) byte = 127;
//            else if (byte <-128) byte = -128;
//            audioBytes[j] = byte;
//        }
//        _mixedSize += mixSize;
//    }
    const char *soundBytes = _soundData.bytes;
    
    if (self.mixingChannels == 2) {
        for (int i = 0; i < buffers.mNumberBuffers; i++) {
            AudioBuffer buf = buffers.mBuffers[i];
            char *audioBytes = buf.mData;
            NSUInteger mixSize = MIN(_soundData.length - _mixedSize, buf.mDataByteSize);
            for (int j = 0; j < buf.mDataByteSize; j += 2) {
                short a = (short)(((audioBytes[j + 1] & 0xFF) << 8) | (audioBytes[j] & 0xFF));
                short b = (short)(((soundBytes[_mixedSize + j + 1] & 0xFF) << 8) | (soundBytes[_mixedSize + j] & 0xFF));
                
                int mixed = (a + b) / 2;
                //int mixed = a + b - a * b / 65536.0;
                audioBytes[j] = mixed & 0xFF;
                audioBytes[j + 1] = (mixed >> 8) & 0xFF;
            }
            _mixedSize += mixSize;
            if (_mixedSize >= _soundData.length && _repeated) {
                [self reset];
            }
        }
    } else {
        for (int i = 0; i < buffers.mNumberBuffers; i++) {
            AudioBuffer buf = buffers.mBuffers[i];
            char *audioBytes = buf.mData;
            for (int j = 0; j < buf.mDataByteSize; j += 2) {
                short a = (short)(((audioBytes[j + 1] & 0xFF) << 8) | (audioBytes[j] & 0xFF));
                short b = (short)(((soundBytes[_mixedSize + 1] & 0xFF) << 8) | (soundBytes[_mixedSize] & 0xFF));
                short c = (short)(((soundBytes[_mixedSize + 3] & 0xFF) << 8) | (soundBytes[_mixedSize + 2] & 0xFF));
                
                int mixed = (a + b + c) / 3;
                //int mixed = a + b + c - (a * b + b * c + c * a) / 65536.0 + a * b * c / (65536.0 * 65536.0) ;
                audioBytes[j] = mixed & 0xFF;
                audioBytes[j + 1] = (mixed >> 8) & 0xFF;
                
                _mixedSize += 2 * 2;
                
                if (_mixedSize >= _soundData.length) {
                    if (_repeated) {
                        [self reset];
                    } else {
                        return;
                    }
                }
            }
        }
    }
}

@end
