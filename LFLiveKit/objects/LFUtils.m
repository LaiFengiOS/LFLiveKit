//
//  LFUtils.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/7/24.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "LFUtils.h"

@implementation LFUtils

+ (UIApplication *)sharedApplication {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
    return hasApplication ? [UIApplicationClass performSelector:@selector(sharedApplication)] : nil;
}

@end
