//
//  RKGPUImageFreedomFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/15.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageFreedomFilter.h"

@implementation RKGPUImageFreedomFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"freedom_map" softLight:@"overlay_softlight2" overlay:nil])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"FREEDOM_FILTER", nil);
}

@end
