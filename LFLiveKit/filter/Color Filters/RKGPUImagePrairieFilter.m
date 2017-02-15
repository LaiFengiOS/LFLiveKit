//
//  RKGPUImagePrairieFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/15.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImagePrairieFilter.h"

@implementation RKGPUImagePrairieFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"prairie_map" softLight:@"overlay_softlight5" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"PRAIRIE_FILTER", nil);
}

@end
