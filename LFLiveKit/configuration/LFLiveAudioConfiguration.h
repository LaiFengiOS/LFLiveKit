//
//  LFLiveAudioConfiguration.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/1.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 音频码率
typedef NS_ENUM (NSUInteger, LFLiveAudioBitRate) {
    /// 32Kbps 音频码率
    LFLiveAudioBitRate_32Kbps = 32000,
    /// 64Kbps 音频码率
    LFLiveAudioBitRate_64Kbps = 64000,
    /// 96Kbps 音频码率
    LFLiveAudioBitRate_96Kbps = 96000,
    /// 128Kbps 音频码率
    LFLiveAudioBitRate_128Kbps = 128000,
    /// 默认音频码率，默认为 64Kbps
    LFLiveAudioBitRate_Default = LFLiveAudioBitRate_64Kbps
};

/// 采样率 (默认44.1Hz iphoneg6以上48Hz)
typedef NS_ENUM (NSUInteger, LFLiveAudioSampleRate){
    /// 44.1Hz 采样率
    LFLiveAudioSampleRate_44100Hz = 44100,
    /// 48Hz 采样率
    LFLiveAudioSampleRate_48000Hz = 48000,
    /// 默认音频码率，默认为 64Kbps
    LFLiveAudioSampleRate_Default = LFLiveAudioSampleRate_44100Hz
};

///  Audio Live quality（音频质量）
typedef NS_ENUM (NSUInteger, LFLiveAudioQuality){
    /// 高音频质量 audio sample rate: 44MHz(默认44.1Hz iphoneg6以上48Hz), audio bitrate: 32Kbps
    LFLiveAudioQuality_Low = 0,
    /// 高音频质量 audio sample rate: 44MHz(默认44.1Hz iphoneg6以上48Hz), audio bitrate: 64Kbps
    LFLiveAudioQuality_Medium = 1,
    /// 高音频质量 audio sample rate: 44MHz(默认44.1Hz iphoneg6以上48Hz), audio bitrate: 96Kbps
    LFLiveAudioQuality_High = 2,
    /// 高音频质量 audio sample rate: 44MHz(默认44.1Hz iphoneg6以上48Hz), audio bitrate: 128Kbps
    LFLiveAudioQuality_VeryHigh = 3,
    /// 默认音频质量 audio sample rate: 44MHz(默认44.1Hz iphoneg6以上48Hz), audio bitrate: 64Kbps
    LFLiveAudioQuality_Default = LFLiveAudioQuality_Medium
};

@interface LFLiveAudioConfiguration : NSObject<NSCoding, NSCopying>

/// 默认音频配置
+ (instancetype)defaultConfiguration;
/// 音频配置
+ (instancetype)defaultConfigurationForQuality:(LFLiveAudioQuality)audioQuality;

#pragma mark - Attribute
///=============================================================================
/// @name Attribute
///=============================================================================
/// 声道数目(default 2)
@property (nonatomic, assign) NSUInteger numberOfChannels;
/// 采样率
@property (nonatomic, assign) LFLiveAudioSampleRate audioSampleRate;
// 码率
@property (nonatomic, assign) LFLiveAudioBitRate audioBitrate;
/// flv编码音频头 44100 为0x12 0x10
@property (nonatomic, assign, readonly) char *asc;

@end
