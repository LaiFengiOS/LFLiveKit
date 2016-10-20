//
//  LFVideoEncoding.h
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFVideoFrame.h"
#import "LFLiveVideoConfiguration.h"

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

