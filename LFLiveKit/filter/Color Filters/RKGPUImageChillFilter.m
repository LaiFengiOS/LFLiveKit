//
//  RKGPUImageChillFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/15.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageChillFilter.h"

@implementation RKGPUImageChillFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"chill_map" softLight:@"overlay_softlight1" overlay:@"overlay_softlight5"])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"CHILL_FILTER", nil);
}

@end
