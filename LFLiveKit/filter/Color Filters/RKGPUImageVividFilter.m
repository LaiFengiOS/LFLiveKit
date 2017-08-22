//
//  RKGPUImageVividFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/15.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageVividFilter.h"

@implementation RKGPUImageVividFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"vivid_map" softLight:@"overlay_softlight1" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"VIVID_FILTER", nil);
}

@end
