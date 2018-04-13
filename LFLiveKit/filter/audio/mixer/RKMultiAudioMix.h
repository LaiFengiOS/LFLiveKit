//
//  RKMultiAudioMix.h
//  LFLiveKit
//
//  Created by Ken Sun on 2017/10/2.
//  Copyright © 2017年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RKAudioMixSource.h"
#import <AVFoundation/AVFoundation.h>

@class RKAudioMixPart;

@interface RKMultiAudioMix : NSObject

+ (void)mixParts:(NSArray<RKAudioMixPart *> *)parts onAudio:(AudioBufferList)buffers;

@end

@interface RKAudioMixPart : NSObject

@property (strong, nonatomic) id<RKAudioMixSource> source;

@property (assign, nonatomic) float weight;

@end
