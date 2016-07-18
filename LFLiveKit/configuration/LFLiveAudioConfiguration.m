//
//  LFLiveAudioConfiguration.m
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/1.
//  Copyright © 2016年 倾慕. All rights reserved.
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
    case LFLiveAudioQuality_Default: {
        audioConfig.audioBitrate = LFLiveAudioBitRate_64Kbps;
    }
    break;
    case LFLiveAudioQuality_Low: {
        audioConfig.audioBitrate = LFLiveAudioBitRate_32Kbps;
    }
    case LFLiveAudioQuality_High: {
        audioConfig.audioBitrate = LFLiveAudioBitRate_96Kbps;
    }
    case LFLiveAudioQuality_VeryHigh: {
        audioConfig.audioBitrate = LFLiveAudioBitRate_128Kbps;
    }
    break;
    default:
        break;
    }
    audioConfig.audioSampleRate = [self.class isNewThaniPhone6] ? LFLiveAudioSampleRate_48000Hz : LFLiveAudioSampleRate_44100Hz;

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
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((self.numberOfChannels & 0xF) << 3);
}

- (void)setNumberOfChannels:(NSUInteger)numberOfChannels {
    _numberOfChannels = numberOfChannels;
    NSInteger sampleRateIndex = [self sampleRateIndex:self.audioSampleRate];
    self.asc[0] = 0x10 | ((sampleRateIndex>>1) & 0x3);
    self.asc[1] = ((sampleRateIndex & 0x1)<<7) | ((numberOfChannels & 0xF) << 3);
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

#pragma mark -- DeviceCategory
+ (NSString *)deviceName {
    struct utsname systemInfo;
    uname(&systemInfo);

    return [NSString stringWithCString:systemInfo.machine
                              encoding:NSUTF8StringEncoding];
}

//@"iPad4,1" on 5th Generation iPad (iPad Air) - Wifi
//@"iPad4,2" on 5th Generation iPad (iPad Air) - Cellular
//@"iPad4,4" on 2nd Generation iPad Mini - Wifi
//@"iPad4,5" on 2nd Generation iPad Mini - Cellular
//@"iPad4,7" on 3rd Generation iPad Mini - Wifi (model A1599)
//@"iPhone7,1" on iPhone 6 Plus
//@"iPhone7,2" on iPhone 6
//@"iPhone8,1" on iPhone 6S
//@"iPhone8,2" on iPhone 6S Plus

+ (BOOL)isNewThaniPhone6 {
    NSString *device = [self deviceName];
    NSLog(@"device %@", device);
    if (device == nil) {
        return NO;
    }
    NSArray *array = [device componentsSeparatedByString:@","];
    if (array.count < 2) {
        return NO;
    }
    NSString *model = [array objectAtIndex:0];
    NSLog(@"model %@", model);
    if ([model hasPrefix:@"iPhone"]) {
        NSString *str1 = [model substringFromIndex:[@"iPhone" length]];
        NSUInteger num = [str1 integerValue];
        NSLog(@"num %lu", (unsigned long)num);
        if (num > 7) {
            return YES;
        }
    }

    if ([model hasPrefix:@"iPad"]) {
        NSString *str1 = [model substringFromIndex:[@"iPad" length]];
        NSUInteger num = [str1 integerValue];
        if (num > 4) {
            return YES;
        }
    }

    return NO;
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
