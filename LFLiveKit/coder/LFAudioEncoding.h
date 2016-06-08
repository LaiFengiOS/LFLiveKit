//
//  LFAudioEncoding.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFAudioFrame.h"
#import "LFLiveAudioConfiguration.h"

@protocol LFAudioEncoding;
/// 编码器编码后回调
@protocol LFAudioEncodingDelegate <NSObject>
@required
- (void)audioEncoder:(nullable id<LFAudioEncoding>)encoder audioFrame:(nullable LFAudioFrame*)frame;
@end

/// 编码器抽象的接口
@protocol LFAudioEncoding <NSObject>
@required
- (void)encodeAudioData:(AudioBufferList)inBufferList timeStamp:(uint64_t)timeStamp;
- (void)stopEncoder;
@optional
- (nullable instancetype)initWithAudioStreamConfiguration:(nullable LFLiveAudioConfiguration*)configuration;
- (void)setDelegate:(nullable id<LFAudioEncodingDelegate>)delegate;
- (nullable NSData*)adtsData:(NSInteger)channel rawDataLength:(NSInteger)rawDataLength;
@end

