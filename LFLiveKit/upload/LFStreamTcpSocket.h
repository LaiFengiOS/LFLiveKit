//
//  LFStreamTcpSocket.h
//  LFLiveKit
//
//  Created by admin on 16/5/3.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#import "LFStreamSocket.h"

@interface LFStreamTcpSocket : NSObject<LFStreamSocket>
#pragma mark - Initializer
///=============================================================================
/// @name Initializer
///=============================================================================
- (nullable instancetype)init UNAVAILABLE_ATTRIBUTE;
+ (nullable instancetype)new UNAVAILABLE_ATTRIBUTE;

@end
