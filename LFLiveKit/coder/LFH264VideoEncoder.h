//
//  LFH264VideoEncoder
//  LFLiveKit
//
//  Created by LaiFeng on 16/5/20.
//  Copyright © 2016年 LaiFeng All rights reserved.
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
