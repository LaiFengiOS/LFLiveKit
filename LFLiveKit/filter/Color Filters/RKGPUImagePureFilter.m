//
//  RKGPUImagePureFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImagePureFilter.h"

@implementation RKGPUImagePureFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"pure_map" softLight:nil overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"PURE_FILTER", nil);
}

@end
