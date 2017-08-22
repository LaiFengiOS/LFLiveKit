//
//  RKGPUImageCalmFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageCalmFilter.h"

@implementation RKGPUImageCalmFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"calm_map" softLight:@"overlay_softlight2" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"CALM_FILTER", nil);
}

@end
