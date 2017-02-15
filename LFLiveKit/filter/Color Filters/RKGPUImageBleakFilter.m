//
//  RKGPUImageBleakFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageBleakFilter.h"

@implementation RKGPUImageBleakFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"bleak_map" softLight:@"overlay_softlight1" overlay:@"overlay_softlight2"])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"BLEAK_FILTER", nil);
}

@end
