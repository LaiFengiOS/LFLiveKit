//
//  RKGPUImageVioletFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageVioletFilter.h"

@implementation RKGPUImageVioletFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"violet_map" softLight:@"overlay_softlight1" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"VIOLET_FILTER", nil);
}

@end
