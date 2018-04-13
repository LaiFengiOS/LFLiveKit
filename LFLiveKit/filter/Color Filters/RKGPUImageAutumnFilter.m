//
//  RKGPUImageAutumnFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/14.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageAutumnFilter.h"

@implementation RKGPUImageAutumnFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"autumn_map" softLight:@"overlay_softlight1" overlay:@"overlay_softlight3"])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"AUTUMN_FILTER", nil);
}

@end
