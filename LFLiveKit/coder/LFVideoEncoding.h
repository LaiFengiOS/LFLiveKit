//
//  LFVideoEncoding.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>

#if __has_include(<LFLiveKit/LFLiveKit.h>)
#import <LFLiveKit/LFVideoFrame.h>
#import <LFLiveKit/LFLiveVideoConfiguration.h>
#else
#import "LFVideoFrame.h"
#import "LFLiveVideoConfiguration.h"
#endif


@protocol LFVideoEncoding;
/// 编码器编码后回调
@protocol LFVideoEncodingDelegate <NSObject>
@required
- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame *)frame;
@end

/// 编码器抽象的接口
@protocol LFVideoEncoding <NSObject>
@required
- (void)encodeVideoData:(nullable CVPixelBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;
@optional
@property (nonatomic, assign) NSInteger videoBitRate;
- (nullable instancetype)initWithVideoStreamConfiguration:(nullable LFLiveVideoConfiguration *)configuration;
- (void)setDelegate:(nullable id<LFVideoEncodingDelegate>)delegate;
- (void)stopEncoder;
@end

