//
//  RKSoundMix.h
//  LFLiveKit
//
//  Created by Ken Sun on 2017/9/4.
//  Copyright © 2017年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RKAudioMix.h"

@interface RKSoundMix : NSObject <RKAudioMix>

@property (strong, nonatomic, readonly, nonnull) NSURL *soundURL;
@property (nonatomic, readonly) BOOL isFinished;

- (instancetype)initWithURL:(nonnull NSURL *)url;

- (void)reset;

@end
