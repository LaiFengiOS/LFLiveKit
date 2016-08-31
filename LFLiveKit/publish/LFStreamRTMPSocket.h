//
//  LFStreamRTMPSocket.h
//  LaiFeng
//
//  Created by admin on 16/5/18.
//  Copyright © 2016年 live Interactive. All rights reserved.
//

#if __has_include(<LFLiveKit/LFLiveKit.h>)
#import <LFLiveKit/LFStreamSocket.h>
#else
#import "LFStreamSocket.h"
#endif

@interface LFStreamRTMPSocket : NSObject<LFStreamSocket>

#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

@end
