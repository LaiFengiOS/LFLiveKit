//
//  LFLiveAudioConfiguration.m
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import "LFLiveAudioConfiguration.h"
#import <sys/utsname.h>

@implementation LFLiveAudioConfiguration

#pragma mark -- LifyCycle
+ (instancetype)defaultConfiguration {
    LFLiveAudioConfiguration *audioConfig = [LFLiveAudioConfiguration defaultConfigurationForQuality:LFLiveAudioQuality_Default];
    return audioConfig;
}

+ (instancetype)defaultConfigurationForQuality:(LFLiveAudioQuality)audioQuality {
    LFLiveAudioConfiguration *audioConfig = [LFLiveAudioConfiguration new];
    audioConfig.numberOfChannels = 2;
    switch (audioQuality) {
    case LFLiveAudioQuality_Low: {
        audioConfig.audioBitrate = audioConfig.numberOfChannels == 1 ? LFLiveAudioBitRate_32Kbps : LFLiveAudioBitRate_64Kbps;
        audioConfig.audioSampleRate = LFLiveAudioSampleRate_16000Hz;
    }
        break;
    case LFLiveAudioQuality_Medium: {
        audioConfig.audioBitrate = LFLiveAudioBitRate_96Kbps;
        audioConfig.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
    }
        break;
    case LFLiveAudioQuality_High: {
        audioConfig.audioBitrate = LFLiveAudioBitRate_128Kbps;
        audioConfig.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
    }
        break;
    case LFLiveAudioQuality_VeryHigh: {
        audioConfig.audioBitrate = LFLiveAudioBitRate_128Kbps;
        audioConfig.audioSampleRate = LFLiveAudioSampleRate_48000Hz;
    }
        break;
    default:{
        audioConfig.audioBitrate = LFLiveAudioBitRate_96Kbps;
        audioConfig.audioSampleRate = LFLiveAudioSampleRate_44100Hz;
    }
        break;
    }

    return audioConfig;
}

- (instancetype)init {
    if (self = [super init]) {
        _asc = malloc(2);
    }
    return self;
}

- (void)dealloc {
    if (_asc) free(_asc);
}

#pragma mark Setter
- (void)setAudioSampleRate:(LFLiveAudioSampleRate)audioSampleRate {
    _audioSampleRate = audioSampleRate;
    NSInteger sampleRateIndex = [self sampleRateIndex:audioSampleRate];
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x7);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((self.numberOfChannels & 0xF) << 3);
}

- (void)setNumberOfChannels:(NSUInteger)numberOfChannels {
    _numberOfChannels = numberOfChannels;
    NSInteger sampleRateIndex = [self sampleRateIndex:self.audioSampleRate];
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x7);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((numberOfChannels & 0xF) << 3);
}

- (NSUInteger)bufferLength{
    return 1024*2*self.numberOfChannels;
}

#pragma mark -- CustomMethod
- (NSInteger)sampleRateIndex:(NSInteger)frequencyInHz {
    NSInteger sampleRateIndex = 0;
    switch (frequencyInHz) {
    case 96000:
        sampleRateIndex = 0;
        break;
    case 88200:
        sampleRateIndex = 1;
        break;
    case 64000:
        sampleRateIndex = 2;
        break;
    case 48000:
        sampleRateIndex = 3;
        break;
    case 44100:
        sampleRateIndex = 4;
        break;
    case 32000:
        sampleRateIndex = 5;
        break;
    case 24000:
        sampleRateIndex = 6;
        break;
    case 22050:
        sampleRateIndex = 7;
        break;
    case 16000:
        sampleRateIndex = 8;
        break;
    case 12000:
        sampleRateIndex = 9;
        break;
    case 11025:
        sampleRateIndex = 10;
        break;
    case 8000:
        sampleRateIndex = 11;
        break;
    case 7350:
        sampleRateIndex = 12;
        break;
    default:
        sampleRateIndex = 15;
    }
    return sampleRateIndex;
}

#pragma mark -- Encoder
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(self.numberOfChannels) forKey:@"numberOfChannels"];
    [aCoder encodeObject:@(self.audioSampleRate) forKey:@"audioSampleRate"];
    [aCoder encodeObject:@(self.audioBitrate) forKey:@"audioBitrate"];
    [aCoder encodeObject:[NSString stringWithUTF8String:self.asc] forKey:@"asc"];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    _numberOfChannels = [[aDecoder decodeObjectForKey:@"numberOfChannels"] unsignedIntegerValue];
    _audioSampleRate = [[aDecoder decodeObjectForKey:@"audioSampleRate"] unsignedIntegerValue];
    _audioBitrate = [[aDecoder decodeObjectForKey:@"audioBitrate"] unsignedIntegerValue];
    _asc = strdup([[aDecoder decodeObjectForKey:@"asc"] cStringUsingEncoding:NSUTF8StringEncoding]);
    return self;
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![super isEqual:other]) {
        return NO;
    } else {
        LFLiveAudioConfiguration *object = other;
        return object.numberOfChannels == self.numberOfChannels &&
               object.audioBitrate == self.audioBitrate &&
               strcmp(object.asc, self.asc) == 0 &&
               object.audioSampleRate == self.audioSampleRate;
    }
}

- (NSUInteger)hash {
    NSUInteger hash = 0;
    NSArray *values = @[@(_numberOfChannels),
                        @(_audioSampleRate),
                        [NSString stringWithUTF8String:self.asc],
                        @(_audioBitrate)];

    for (NSObject *value in values) {
        hash ^= value.hash;
    }
    return hash;
}

- (id)copyWithZone:(nullable NSZone *)zone {
    LFLiveAudioConfiguration *other = [self.class defaultConfiguration];
    return other;
}

- (NSString *)description {
    NSMutableString *desc = @"".mutableCopy;
    [desc appendFormat:@"<LFLiveAudioConfiguration: %p>", self];
    [desc appendFormat:@" numberOfChannels:%zi", self.numberOfChannels];
    [desc appendFormat:@" audioSampleRate:%zi", self.audioSampleRate];
    [desc appendFormat:@" audioBitrate:%zi", self.audioBitrate];
    [desc appendFormat:@" audioHeader:%@", [NSString stringWithUTF8String:self.asc]];
    return desc;
}

@end
