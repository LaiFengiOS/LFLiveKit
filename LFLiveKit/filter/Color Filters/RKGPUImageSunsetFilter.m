//
//  RKGPUImageSunsetFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageSunsetFilter.h"

@implementation RKGPUImageSunsetFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"sunset_map" softLight:@"overlay_softlight1" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"SUNSET_FILTER", nil);
}

@end
