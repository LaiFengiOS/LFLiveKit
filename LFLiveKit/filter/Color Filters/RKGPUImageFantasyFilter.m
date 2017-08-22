//
//  RKGPUImageFantasyFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/15.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageFantasyFilter.h"

@implementation RKGPUImageFantasyFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"fantasy_map" softLight:@"overlay_softlight4" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"FANTASY_FILTER", nil);
}

@end
