//
//  RKGPUImageOceanFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageOceanFilter.h"

@implementation RKGPUImageOceanFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"ocean_map" softLight:@"overlay_softlight1" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"OCEAN_FILTER", nil);
}

@end
