//
//  LFVideoEncoding.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFVideoFrame.h"
#import "LFLiveVideoConfiguration.h"

@protocol LFVideoEncoding;
/// 编码器编码后回调
@protocol LFVideoEncodingDelegate <NSObject>
@required
- (void)videoEncoder:(nullable id<LFVideoEncoding>)encoder videoFrame:(nullable LFVideoFrame*)frame;
@end

/// 编码器抽象的接口
@protocol LFVideoEncoding <NSObject>
@required
- (void)encodeVideoData:(nullable CVImageBufferRef)pixelBuffer timeStamp:(uint64_t)timeStamp;
- (void)stopEncoder;
@optional
@property (nonatomic, assign) NSInteger videoBitRate;
- (nullable instancetype)initWithVideoStreamConfiguration:(nullable LFLiveVideoConfiguration*)configuration;
- (void)setDelegate:(nullable id<LFVideoEncodingDelegate>)delegate;

@end

