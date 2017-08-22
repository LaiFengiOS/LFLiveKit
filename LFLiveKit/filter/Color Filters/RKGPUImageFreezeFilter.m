//
//  RKGPUImageFreezeFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageFreezeFilter.h"

@implementation RKGPUImageFreezeFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"freeze_map" softLight:@"overlay_softlight1" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"FREEZE_FILTER", nil);
}

@end
