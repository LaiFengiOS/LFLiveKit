//
//  LFH264VideoEncoder
//  LFLiveKit
//
//  Created by feng on 7/5/16.
//  Copyright (c) 2014 zhanqi.tv. All rights reserved.
//

#if __has_include(<LFLiveKit/LFLiveKit.h>)
#import <LFLiveKit/LFVideoEncoding.h>
#else
#import "LFVideoEncoding.h"
#endif

@interface LFH264VideoEncoder : NSObject <LFVideoEncoding> {
 
}

- (void)shutdown;

@end
