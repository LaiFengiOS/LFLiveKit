//
//  RKAudioMix.h
//  LFLiveKit
//
//  Created by Ken Sun on 2017/9/4.
//  Copyright © 2017年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol RKAudioMix <NSObject>

- (void)process:(AudioBufferList)buffers;

@end

@interface RKAudioDataMix : NSObject <RKAudioMix>

- (void)pushData:(nonnull NSData *)data;

@end
