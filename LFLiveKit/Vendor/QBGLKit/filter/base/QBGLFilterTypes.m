//
//  QBGLFilterTypes.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/22.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLFilterTypes.h"

@implementation QBGLFilterTypes

+ (NSArray<NSString*> *)filterNames {
    static NSArray *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @[NSLocalizedString(@"NORMAL_FILTER", nil),
//                  NSLocalizedString(@"RICH_FILTER", nil),
                  NSLocalizedString(@"WARM_FILTER", nil),
                  NSLocalizedString(@"SOFT_FILTER", nil),
                  NSLocalizedString(@"ROSE_FILTER", nil),
                  NSLocalizedString(@"MORNING_FILTER", nil),
                  NSLocalizedString(@"SUNSHINE_FILTER", nil),
                  NSLocalizedString(@"SUNSET_FILTER", nil),
                  NSLocalizedString(@"COOL_FILTER", nil),
                  NSLocalizedString(@"FREEZE_FILTER", nil),
                  NSLocalizedString(@"OCEAN_FILTER", nil),
                  NSLocalizedString(@"DREAM_FILTER", nil),
                  NSLocalizedString(@"VIOLET_FILTER", nil),
                  NSLocalizedString(@"MELLOW_FILTER", nil),
//                  NSLocalizedString(@"BLEAK_FILTER", nil),
                  NSLocalizedString(@"MEMORY_FILTER", nil),
                  NSLocalizedString(@"PURE_FILTER", nil),
                  NSLocalizedString(@"CALM_FILTER", nil),
                  NSLocalizedString(@"AUTUMN_FILTER", nil),
                  NSLocalizedString(@"FANTASY_FILTER", nil),
                  NSLocalizedString(@"FREEDOM_FILTER", nil),
                  NSLocalizedString(@"MILD_FILTER", nil),
                  NSLocalizedString(@"PRAIRIE_FILTER", nil),
                  NSLocalizedString(@"DEEP_FILTER", nil),
                  NSLocalizedString(@"GLOW_FILTER", nil),
//                  NSLocalizedString(@"MEMOIR_FILTER", nil),
                  NSLocalizedString(@"MIST_FILTER", nil),
                  NSLocalizedString(@"VIVID_FILTER", nil),
//                  NSLocalizedString(@"CHILL_FILTER", nil),
                  NSLocalizedString(@"PINKY_FILTER", nil),
                  NSLocalizedString(@"ADVENTURE_FILTER", nil),
//                  NSLocalizedString(@"MAGIC_AMARO", nil),
//                  NSLocalizedString(@"MAGIC_ANTIQUE", nil),
//                  NSLocalizedString(@"MAGIC_BLACKCAT", nil),
//                  NSLocalizedString(@"MAGIC_BRANNAN", nil),
//                  NSLocalizedString(@"MAGIC_BROOKLYN", nil),
//                  NSLocalizedString(@"MAGIC_CALM", nil),
//                  NSLocalizedString(@"MAGIC_COOL", nil),
//                  NSLocalizedString(@"MAGIC_CRAYON", nil),
//                  NSLocalizedString(@"MAGIC_EARLYBIRD", nil),
//                  NSLocalizedString(@"MAGIC_EMERALD", nil),
//                  NSLocalizedString(@"MAGIC_EVERGREEN", nil),
//                  NSLocalizedString(@"MAGIC_FAIRYTALE", nil),
//                  NSLocalizedString(@"MAGIC_FREUD", nil),
//                  NSLocalizedString(@"MAGIC_HUDSON", nil),
//                  NSLocalizedString(@"MAGIC_INKWELL", nil),
//                  NSLocalizedString(@"MAGIC_KEVIN", nil),
//                  NSLocalizedString(@"MAGIC_LATTE", nil),
//                  NSLocalizedString(@"MAGIC_N1977", nil),
//                  NSLocalizedString(@"MAGIC_NASHVILLER", nil),
//                  NSLocalizedString(@"MAGIC_NOSTALGIA", nil),
//                  NSLocalizedString(@"MAGIC_PIXAR", nil),
//                  NSLocalizedString(@"MAGIC_RISE", nil),
//                  NSLocalizedString(@"MAGIC_ROMANCE", nil),
//                  NSLocalizedString(@"MAGIC_SIERRA", nil),
//                  NSLocalizedString(@"MAGIC_SKETCH", nil),
//                  NSLocalizedString(@"MAGIC_SKINWHITE", nil),
//                  NSLocalizedString(@"MAGIC_SUNRISE", nil),
//                  NSLocalizedString(@"MAGIC_SUNSET", nil),
//                  NSLocalizedString(@"MAGIC_SUTRO", nil),
//                  NSLocalizedString(@"MAGIC_TENDER", nil),
//                  NSLocalizedString(@"MAGIC_TOASTER", nil),
//                  NSLocalizedString(@"MAGIC_VALENCIA", nil),
//                  NSLocalizedString(@"MAGIC_WALDEN", nil),
//                  NSLocalizedString(@"MAGIC_WARM", nil),
//                  NSLocalizedString(@"MAGIC_WHITECAT", nil),
//                  NSLocalizedString(@"MAGIC_XPROLL", nil)
                  ];
    });
    return names;
}

+ (NSString *)filterNameAtIndex:(NSUInteger)index {
    return [self filterNames][index];
}

+ (NSString *)filterNameForType:(QBGLFilterType)type {
    return [self filterNames][type];
}

+ (QBGLFilterType)nextFilterForType:(QBGLFilterType)type {
    return type + 1 < [self filterNames].count ? type + 1 : 0;
}

+ (QBGLFilterType)previousFilterForType:(QBGLFilterType)type {
    return type - 1 >= 0 ? type - 1 : [self filterNames].count - 1;
}

@end
