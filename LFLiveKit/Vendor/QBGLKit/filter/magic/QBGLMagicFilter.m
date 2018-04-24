//
//  QBGLMagicFilter.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/25.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLMagicFilter.h"
#import "QBGLAmaroFilter.h"
#import "QBGLAntiqueFilter.h"
#import "QBGLBlackCatFilter.h"
#import "QBGLBrannanFilter.h"
#import "QBGLBrooklynFilter.h"
#import "QBGLCalmFilter.h"
#import "QBGLCoolFilter.h"
#import "QBGLCrayonFilter.h"
#import "QBGLEarlyBirdFilter.h"
#import "QBGLEmeraldFilter.h"
#import "QBGLEvergreenFilter.h"
#import "QBGLFairytaleFilter.h"
#import "QBGLFreudFilter.h"
#import "QBGLHealthyFilter.h"
#import "QBGLHudsonFilter.h"
#import "QBGLInkwellFilter.h"
#import "QBGLKevinFilter.h"
#import "QBGLLatteFilter.h"
#import "QBGLLomoFilter.h"
#import "QBGLN1977Filter.h"
#import "QBGLNashVillerFilter.h"
#import "QBGLNostalgiaFilter.h"
#import "QBGLPixarFilter.h"
#import "QBGLRiseFilter.h"
#import "QBGLRomanceFilter.h"
#import "QBGLSakuraFilter.h"
#import "QBGLSierraFilter.h"
#import "QBGLSketchFilter.h"
#import "QBGLSkinWhiteFilter.h"
#import "QBGLSunriseFilter.h"
#import "QBGLSunsetFilter.h"
#import "QBGLSutroFilter.h"
#import "QBGLSweetsFilter.h"
#import "QBGLTenderFilter.h"
#import "QBGLToasterFilter.h"
#import "QBGLValenciaFilter.h"
#import "QBGLWaldenFilter.h"
#import "QBGLWarmFilter.h"
#import "QBGLWhiteCatFilter.h"
#import "QBGLXprollFilter.h"
#import "QBGLMagicFilterBase.h"

@implementation QBGLMagicFilter

+ (QBGLMagicFilterBase *)amaroFilter {
    return [[QBGLAmaroFilter alloc] init];
}

+ (QBGLMagicFilterBase *)antiqueFilter {
    return [[QBGLAntiqueFilter alloc] init];
}

+ (QBGLMagicFilterBase *)blackCatFilter {
    return [[QBGLBlackCatFilter alloc] init];
}

+ (QBGLMagicFilterBase *)brannanFilter {
    return [[QBGLBrannanFilter alloc] init];
}

+ (QBGLMagicFilterBase *)brooklynFilter {
    return [[QBGLBrooklynFilter alloc] init];
}

+ (QBGLMagicFilterBase *)magicCalmFilter {
    return [[QBGLCalmFilter alloc] init];
}

+ (QBGLMagicFilterBase *)magicCoolFilter {
    return [[QBGLCoolFilter alloc] init];
}

+ (QBGLMagicFilterBase *)crayonFilter {
    return [[QBGLCrayonFilter alloc] init];
}

+ (QBGLMagicFilterBase *)earlyBirdFilter {
    return [[QBGLEarlyBirdFilter alloc] init];
}

+ (QBGLMagicFilterBase *)emeraldFilter {
    return [[QBGLEmeraldFilter alloc] init];
}

+ (QBGLMagicFilterBase *)evergreenFilter {
    return [[QBGLEvergreenFilter alloc] init];
}

+ (QBGLMagicFilterBase *)fairytaleFilter {
    return [[QBGLFairytaleFilter alloc] init];
}

+ (QBGLMagicFilterBase *)freudFilter {
    return [[QBGLFreudFilter alloc] init];
}

+ (QBGLMagicFilterBase *)healthyFilter {
    return [[QBGLHealthyFilter alloc] init];
}

+ (QBGLMagicFilterBase *)hudsonFilter {
    return [[QBGLHudsonFilter alloc] init];
}

+ (QBGLMagicFilterBase *)inkwellFilter {
    return [[QBGLInkwellFilter alloc] init];
}

+ (QBGLMagicFilterBase *)kevinFilter {
    return [[QBGLKevinFilter alloc] init];
}

+ (QBGLMagicFilterBase *)latteFilter {
    return [[QBGLLatteFilter alloc] init];
}

+ (QBGLMagicFilterBase *)lomoFilter {
    return [[QBGLLomoFilter alloc] init];
}

+ (QBGLMagicFilterBase *)n1977Filter {
    return [[QBGLN1977Filter alloc] init];
}

+ (QBGLMagicFilterBase *)nashVillerFilter {
    return [[QBGLNashVillerFilter alloc] init];
}

+ (QBGLMagicFilterBase *)nostalgiaFilter {
    return [[QBGLNostalgiaFilter alloc] init];
}

+ (QBGLMagicFilterBase *)pixarFilter {
    return [[QBGLPixarFilter alloc] init];
}

+ (QBGLMagicFilterBase *)riseFilter {
    return [[QBGLRiseFilter alloc] init];
}

+ (QBGLMagicFilterBase *)romanceFilter {
    return [[QBGLRomanceFilter alloc] init];
}

+ (QBGLMagicFilterBase *)sakuraFilter {
    return [[QBGLSakuraFilter alloc] init];
}

+ (QBGLMagicFilterBase *)sierraFilter {
    return [[QBGLSierraFilter alloc] init];
}

+ (QBGLMagicFilterBase *)sketchFilter {
    return [[QBGLSketchFilter alloc] init];
}

+ (QBGLMagicFilterBase *)skinWhiteFilter {
    return [[QBGLSkinWhiteFilter alloc] init];
}

+ (QBGLMagicFilterBase *)sunriseFilter {
    return [[QBGLSunriseFilter alloc] init];
}

+ (QBGLMagicFilterBase *)sunsetFilter {
    return [[QBGLSunsetFilter alloc] init];
}

+ (QBGLMagicFilterBase *)sutroFilter {
    return [[QBGLSutroFilter alloc] init];
}

+ (QBGLMagicFilterBase *)sweetsFilter {
    return [[QBGLSweetsFilter alloc] init];
}

+ (QBGLMagicFilterBase *)tenderFilter {
    return [[QBGLTenderFilter alloc] init];
}

+ (QBGLMagicFilterBase *)toasterFilter {
    return [[QBGLToasterFilter alloc] init];
}

+ (QBGLMagicFilterBase *)valenciaFilter {
    return [[QBGLValenciaFilter alloc] init];
}

+ (QBGLMagicFilterBase *)waldenFilter {
    return [[QBGLWaldenFilter alloc] init];
}

+ (QBGLMagicFilterBase *)warmFilter {
    return [[QBGLWarmFilter alloc] init];
}

+ (QBGLMagicFilterBase *)whiteCatFilter {
    return [[QBGLWhiteCatFilter alloc] init];
}

+ (QBGLMagicFilterBase *)xprollFilter {
    return [[QBGLXprollFilter alloc] init];
}

@end
