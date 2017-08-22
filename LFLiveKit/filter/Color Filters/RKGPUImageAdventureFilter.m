//
//  RKGPUImageAdventureFilter.m
//  LFLiveKit
//
//  Created by Racing on 2017/2/15.
//  Copyright © 2017年 admin. All rights reserved.
//

#import "RKGPUImageAdventureFilter.h"

@implementation RKGPUImageAdventureFilter

#pragma mark - LifeCycle

- (instancetype)init {
    if (!(self = [self initWithColorMap:@"adventure_map" softLight:@"overlay_softlight2" overlay:@"overlay_softlight3"])) {
        return nil;
    }
    
    return self;
}

#pragma mark - Accessor

- (NSString *)localizedName {
    return NSLocalizedString(@"ADVENTURE_FILTER", nil);
}

@end
