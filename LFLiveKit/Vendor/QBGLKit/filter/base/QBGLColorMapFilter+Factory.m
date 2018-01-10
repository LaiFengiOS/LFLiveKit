//
//  QBGLColorMapFilter+Factory.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/23.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLColorMapFilter+Factory.h"

@implementation QBGLColorMapFilter (Factory)

+ (instancetype)richFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"rich_map" overlay1:@"overlay_softlight6" overlay2:nil localizedName:NSLocalizedString(@"RICH_FILTER", nil)];
}

+ (instancetype)warmFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"warm_map" overlay1:@"overlay_softlight2" overlay2:nil localizedName:NSLocalizedString(@"WARM_FILTER", nil)];
}

+ (instancetype)softFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"soft_map" overlay1:nil overlay2:nil localizedName:NSLocalizedString(@"SOFT_FILTER", nil)];
}

+ (instancetype)roseFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"rose_map" overlay1:nil overlay2:nil localizedName:NSLocalizedString(@"ROSE_FILTER", nil)];
}

+ (instancetype)morningFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"morning_map" overlay1:nil overlay2:nil localizedName:NSLocalizedString(@"MORNING_FILTER", nil)];
}

+ (instancetype)sunshineFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"sunshine_map" overlay1:@"overlay_softlight2" overlay2:nil localizedName:NSLocalizedString(@"SUNSHINE_FILTER", nil)];
}

+ (instancetype)sunsetFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"sunset_map" overlay1:@"overlay_softlight1" overlay2:nil localizedName:NSLocalizedString(@"SUNSET_FILTER", nil)];
}

+ (instancetype)coolFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"cool_map" overlay1:@"overlay_softlight2" overlay2:nil localizedName:NSLocalizedString(@"COOL_FILTER", nil)];
}

+ (instancetype)freezeFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"freeze_map" overlay1:@"overlay_softlight1" overlay2:nil localizedName:NSLocalizedString(@"FREEZE_FILTER", nil)];
}

+ (instancetype)oceanFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"ocean_map" overlay1:@"overlay_softlight1" overlay2:nil localizedName:NSLocalizedString(@"OCEAN_FILTER", nil)];
}

+ (instancetype)dreamFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"dream_map" overlay1:@"overlay_softlight3" overlay2:nil localizedName:NSLocalizedString(@"DREAM_FILTER", nil)];
}

+ (instancetype)violetFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"violet_map" overlay1:@"overlay_softlight1" overlay2:nil localizedName:NSLocalizedString(@"VIOLET_FILTER", nil)];
}

+ (instancetype)mellowFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"mellow_map" overlay1:@"overlay_softlight6" overlay2:nil localizedName:NSLocalizedString(@"MELLOW_FILTER", nil)];
}

+ (instancetype)bleakFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"bleak_map" overlay1:@"overlay_softlight1" overlay2:@"overlay_softlight2" localizedName:NSLocalizedString(@"BLEAK_FILTER", nil)];
}

+ (instancetype)memoryFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"memory_map" overlay1:@"overlay_softlight1" overlay2:@"overlay_softlight3" localizedName:NSLocalizedString(@"MEMORY_FILTER", nil)];
}

+ (instancetype)pureFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"pure_map" overlay1:nil overlay2:nil localizedName:NSLocalizedString(@"PURE_FILTER", nil)];
}

+ (instancetype)calmFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"calm_map" overlay1:@"overlay_softlight2" overlay2:nil localizedName:NSLocalizedString(@"CALM_FILTER", nil)];
}

+ (instancetype)autumnFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"autumn_map" overlay1:@"overlay_softlight1" overlay2:@"overlay_softlight3" localizedName:NSLocalizedString(@"AUTUMN_FILTER", nil)];
}

+ (instancetype)fantasyFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"fantasy_map" overlay1:@"overlay_softlight4" overlay2:nil localizedName:NSLocalizedString(@"FANTASY_FILTER", nil)];
}

+ (instancetype)freedomFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"freedom_map" overlay1:@"overlay_softlight2" overlay2:nil localizedName:NSLocalizedString(@"FREEDOM_FILTER", nil)];
}

+ (instancetype)mildFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"mild_map" overlay1:@"overlay_softlight5" overlay2:nil localizedName:NSLocalizedString(@"MILD_FILTER", nil)];
}

+ (instancetype)prairieFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"prairie_map" overlay1:@"overlay_softlight5" overlay2:nil localizedName:NSLocalizedString(@"PRAIRIE_FILTER", nil)];
}

+ (instancetype)deepFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"deep_map" overlay1:@"overlay_softlight2" overlay2:nil localizedName:NSLocalizedString(@"DEEP_FILTER", nil)];
}

+ (instancetype)glowFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"glow_map" overlay1:@"overlay_softlight5" overlay2:nil localizedName:NSLocalizedString(@"GLOW_FILTER", nil)];
}

+ (instancetype)memoirFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"memoir_map" overlay1:@"overlay_softlight6" overlay2:nil localizedName:NSLocalizedString(@"MEMOIR_FILTER", nil)];
}

+ (instancetype)mistFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"mist_map" overlay1:@"overlay_softlight5" overlay2:nil localizedName:NSLocalizedString(@"MIST_FILTER", nil)];
}

+ (instancetype)vividFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"vivid_map" overlay1:@"overlay_softlight1" overlay2:nil localizedName:NSLocalizedString(@"VIVID_FILTER", nil)];
}

+ (instancetype)chillFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"chill_map" overlay1:@"overlay_softlight1" overlay2:@"overlay_softlight5" localizedName:NSLocalizedString(@"CHILL_FILTER", nil)];
}

+ (instancetype)pinkFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"pinky_map" overlay1:@"overlay_softlight5" overlay2:nil localizedName:NSLocalizedString(@"PINK_FILTER", nil)];
}

+ (instancetype)adventureFilter {
    return [[QBGLColorMapFilter alloc] initWithColorMap:@"adventure_map" overlay1:@"overlay_softlight2" overlay2:@"overlay_softlight3" localizedName:NSLocalizedString(@"ADVENTURE_FILTER", nil)];
}

@end
