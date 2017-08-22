//
//  RKGPUImageMemoirFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/15.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageMemoirFilter.h"

@implementation RKGPUImageMemoirFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"memoir_map" softLight:@"overlay_softlight6" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"MEMOIR_FILTER", nil);
}

@end
