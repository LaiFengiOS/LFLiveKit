//
//  LFHardwareVideoEncoder.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#if __has_include(<LFLiveKit/LFLiveKit.h>)
#import <LFLiveKit/LFVideoEncoding.h>
#else
#import "LFVideoEncoding.h"
#endif

@interface LFHardwareVideoEncoder : NSObject<LFVideoEncoding>

#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

@end
