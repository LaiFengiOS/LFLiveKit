//
//  LFAudioFrame.h
//  LFLiveKit
//
//  Created by 倾慕 on 16/5/2.
//  Copyright © 2016年 倾慕. All rights reserved.
//

#if __has_include(<LFLiveKit/LFLiveKit.h>)
#import <LFLiveKit/LFFrame.h>
#else
#import "LFFrame.h"
#endif

@interface LFAudioFrame : LFFrame

/// flv打包中aac的header
@property (nonatomic, strong) NSData *audioInfo;

@end
