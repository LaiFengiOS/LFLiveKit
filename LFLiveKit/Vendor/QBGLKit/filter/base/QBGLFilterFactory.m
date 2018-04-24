//
//  QBGLFilterFactory.m
//  Qubi
//
//  Created by Ken Sun on 2016/8/22.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLFilterFactory.h"
#import "QBGLFilter.h"
#import "QBGLColorMapFilter+Factory.h"
#import "QBGLMagicFilter.h"

@interface QBGLFilterFactory ()

@property (strong, nonatomic) NSMutableDictionary<NSNumber*, QBGLFilter*> *filterCache;

@end

@implementation QBGLFilterFactory

- (instancetype)init {
    if (self = [super init]) {
        _cacheEnabled = YES;
        _filterCache = [NSMutableDictionary new];
    }
    return self;
}

- (QBGLFilter *)filterWithType:(QBGLFilterType)type {
    QBGLFilter *filter = _cacheEnabled ? _filterCache[@(type)] : nil;
    if (!filter) {
        filter = [self.class createFilterWithType:type];
    }
    if (_cacheEnabled) {
        _filterCache[@(type)] = filter;
    }
    return filter;
}

- (void)clearCache {
    [_filterCache removeAllObjects];
}

+ (QBGLFilter *)createFilterWithType:(QBGLFilterType)type {
    switch (type) {
        case QBGLFilterTypeNone:
            return [[QBGLFilter alloc] init];
//        case QBGLFilterTypeRich:
//            return [QBGLColorMapFilter richFilter];
        case QBGLFilterTypeWarm:
            return [QBGLColorMapFilter warmFilter];
        case QBGLFilterTypeSoft:
            return [QBGLColorMapFilter softFilter];
        case QBGLFilterTypeRose:
            return [QBGLColorMapFilter roseFilter];
        case QBGLFilterTypeMorning:
            return [QBGLColorMapFilter morningFilter];
        case QBGLFilterTypeSunshine:
            return [QBGLColorMapFilter sunshineFilter];
        case QBGLFilterTypeSunset:
            return [QBGLColorMapFilter sunsetFilter];
        case QBGLFilterTypeCool:
            return [QBGLColorMapFilter coolFilter];
        case QBGLFilterTypeFreeze:
            return [QBGLColorMapFilter freezeFilter];
        case QBGLFilterTypeOcean:
            return [QBGLColorMapFilter oceanFilter];
        case QBGLFilterTypeDream:
            return [QBGLColorMapFilter dreamFilter];
        case QBGLFilterTypeViolet:
            return [QBGLColorMapFilter violetFilter];
        case QBGLFilterTypeMellow:
            return [QBGLColorMapFilter mellowFilter];
//        case QBGLFilterTypeBleak:
//            return [QBGLColorMapFilter bleakFilter];
        case QBGLFilterTypeMemory:
            return [QBGLColorMapFilter memoryFilter];
        case QBGLFilterTypePure:
            return [QBGLColorMapFilter pureFilter];
        case QBGLFilterTypeCalm:
            return [QBGLColorMapFilter calmFilter];
        case QBGLFilterTypeAutumn:
            return [QBGLColorMapFilter autumnFilter];
        case QBGLFilterTypeFantasy:
            return [QBGLColorMapFilter fantasyFilter];
        case QBGLFilterTypeFreedom:
            return [QBGLColorMapFilter freedomFilter];
        case QBGLFilterTypeMild:
            return [QBGLColorMapFilter mildFilter];
        case QBGLFilterTypePrairie:
            return [QBGLColorMapFilter prairieFilter];
        case QBGLFilterTypeDeep:
            return [QBGLColorMapFilter deepFilter];
        case QBGLFilterTypeGlow:
            return [QBGLColorMapFilter glowFilter];
//        case QBGLFilterTypeMemoir:
//            return [QBGLColorMapFilter memoirFilter];
        case QBGLFilterTypeMist:
            return [QBGLColorMapFilter mistFilter];
        case QBGLFilterTypeVivid:
            return [QBGLColorMapFilter vividFilter];
//        case QBGLFilterTypeChill:
//            return [QBGLColorMapFilter chillFilter];
        case QBGLFilterTypePinky:
            return [QBGLColorMapFilter pinkFilter];
        case QBGLFilterTypeAdventure:
            return [QBGLColorMapFilter adventureFilter];
            
//        case QBGLFilterTypeAmaro:
//            return [QBGLMagicFilter amaroFilter];
//        case QBGLFilterTypeAntique:
//            return [QBGLMagicFilter antiqueFilter];
//        case QBGLFilterTypeBlackCat:
//            return [QBGLMagicFilter blackCatFilter];
//        case QBGLFilterTypeBrannan:
//            return [QBGLMagicFilter brannanFilter];
//        case QBGLFilterTypeBrooklyn:
//            return [QBGLMagicFilter brooklynFilter];
//        case QBGLFilterTypeMagicCalm:
//            return [QBGLMagicFilter magicCalmFilter];
//        case QBGLFilterTypeMagicCool:
//            return [QBGLMagicFilter magicCoolFilter];
        case QBGLFilterTypeCrayon:
            return [QBGLMagicFilter crayonFilter];
//        case QBGLFilterTypeEarlybird:
//            return [QBGLMagicFilter earlyBirdFilter];
//        case QBGLFilterTypeEmerald:
//            return [QBGLMagicFilter emeraldFilter];
//        case QBGLFilterTypeEvergreen:
//            return [QBGLMagicFilter evergreenFilter];
        case QBGLFilterTypeFairytale:
            return [QBGLMagicFilter fairytaleFilter];
//        case QBGLFilterTypeFreud:
//            return [QBGLMagicFilter freudFilter];
//        case QBGLFilterTypeHealthy:
//            return [QBGLMagicFilter healthyFilter];
//        case QBGLFilterTypeHudson:
//            return [QBGLMagicFilter hudsonFilter];
        case QBGLFilterTypeInkwell:
            return [QBGLMagicFilter inkwellFilter];
//        case QBGLFilterTypeKevin:
//            return [QBGLMagicFilter kevinFilter];
//        case QBGLFilterTypeLatte:
//            return [QBGLMagicFilter latteFilter];
//        case QBGLFilterTypeLomo:
//            return [QBGLMagicFilter lomoFilter];
        case QBGLFilterTypeN1977:
            return [QBGLMagicFilter n1977Filter];
//        case QBGLFilterTypeNashViller:
//            return [QBGLMagicFilter nashVillerFilter];
//        case QBGLFilterTypeNostalgia:
//            return [QBGLMagicFilter nostalgiaFilter];
        case QBGLFilterTypePixar:
            return [QBGLMagicFilter pixarFilter];
//        case QBGLFilterTypeRise:
//            return [QBGLMagicFilter riseFilter];
        case QBGLFilterTypeRomance:
            return [QBGLMagicFilter romanceFilter];
//        case QBGLFilterTypeSakura:
//            return [QBGLMagicFilter sakuraFilter];
//        case QBGLFilterTypeSierra:
//            return [QBGLMagicFilter sierraFilter];
        case QBGLFilterTypeSketch:
            return [QBGLMagicFilter sketchFilter];
//        case QBGLFilterTypeSkinWhite:
//            return [QBGLMagicFilter skinWhiteFilter];
//        case QBGLFilterTypeSunrise:
//            return [QBGLMagicFilter sunriseFilter];
//        case QBGLFilterTypeMagicSunset:
//            return [QBGLMagicFilter sunsetFilter];
//        case QBGLFilterTypeSutro:
//            return [QBGLMagicFilter sutroFilter];
//        case QBGLFilterTypeSweets:
//            return [QBGLMagicFilter sweetsFilter];
//        case QBGLFilterTypeTender:
//            return [QBGLMagicFilter tenderFilter];
//        case QBGLFilterTypeToaster:
//            return [QBGLMagicFilter toasterFilter];
//        case QBGLFilterTypeValencia:
//            return [QBGLMagicFilter valenciaFilter];
        case QBGLFilterTypeWalden:
            return [QBGLMagicFilter waldenFilter];
//        case QBGLFilterTypeMagicWarm:
//            return [QBGLMagicFilter warmFilter];
//        case QBGLFilterTypeWhiteCat:
//            return [QBGLMagicFilter whiteCatFilter];
//        case QBGLFilterTypeXproll:
//            return [QBGLMagicFilter xprollFilter];
    }
    return nil;
}

+ (void)refactorColorFilter:(QBGLColorMapFilter *)filter withType:(QBGLFilterType)type {
    switch (type) {
        case QBGLFilterTypeNone:
            filter.colorMapName = filter.overlayName1 = filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"NORMAL_FILTER", nil);
            break;
        case QBGLFilterTypeWarm:
            filter.colorMapName = @"warm_map";
            filter.overlayName1 = @"overlay_softlight2";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"WARM_FILTER", nil);
            break;
        case QBGLFilterTypeSoft:
            filter.colorMapName = @"soft_map";
            filter.overlayName1 = nil;
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"SOFT_FILTER", nil);
            break;
        case QBGLFilterTypeRose:
            filter.colorMapName = @"rose_map";
            filter.overlayName1 = nil;
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"ROSE_FILTER", nil);
            break;
        case QBGLFilterTypeMorning:
            filter.colorMapName = @"morning_map";
            filter.overlayName1 = nil;
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"MORNING_FILTER", nil);
            break;
        case QBGLFilterTypeSunshine:
            filter.colorMapName = @"sunshine_map";
            filter.overlayName1 = @"overlay_softlight2";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"SUNSHINE_FILTER", nil);
            break;
        case QBGLFilterTypeSunset:
            filter.colorMapName = @"sunset_map";
            filter.overlayName1 = @"overlay_softlight1";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"SUNSET_FILTER", nil);
            break;
        case QBGLFilterTypeCool:
            filter.colorMapName = @"cool_map";
            filter.overlayName1 = @"overlay_softlight2";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"COOL_FILTER", nil);
            break;
        case QBGLFilterTypeFreeze:
            filter.colorMapName = @"freeze_map";
            filter.overlayName1 = @"overlay_softlight1";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"FREEZE_FILTER", nil);
            break;
        case QBGLFilterTypeOcean:
            filter.colorMapName = @"ocean_map";
            filter.overlayName1 = @"overlay_softlight1";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"OCEAN_FILTER", nil);
            break;
        case QBGLFilterTypeDream:
            filter.colorMapName = @"dream_map";
            filter.overlayName1 = @"overlay_softlight3";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"DREAM_FILTER", nil);
            break;
        case QBGLFilterTypeViolet:
            filter.colorMapName = @"violet_map";
            filter.overlayName1 = @"overlay_softlight1";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"VIOLET_FILTER", nil);
            break;
        case QBGLFilterTypeMellow:
            filter.colorMapName = @"mellow_map";
            filter.overlayName1 = @"overlay_softlight6";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"MELLOW_FILTER", nil);
            break;
        case QBGLFilterTypeMemory:
            filter.colorMapName = @"memory_map";
            filter.overlayName1 = @"overlay_softlight1";
            filter.overlayName2 = @"overlay_softlight3";
            filter.localizedName = NSLocalizedString(@"MEMORY_FILTER", nil);
            break;
        case QBGLFilterTypePure:
            filter.colorMapName = @"pure_map";
            filter.overlayName1 = nil;
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"PURE_FILTER", nil);
            break;
        case QBGLFilterTypeCalm:
            filter.colorMapName = @"calm_map";
            filter.overlayName1 = @"overlay_softlight2";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"CALM_FILTER", nil);
            break;
        case QBGLFilterTypeAutumn:
            filter.colorMapName = @"autumn_map";
            filter.overlayName1 = @"overlay_softlight1";
            filter.overlayName2 = @"overlay_softlight3";
            filter.localizedName = NSLocalizedString(@"AUTUMN_FILTER", nil);
            break;
        case QBGLFilterTypeFantasy:
            filter.colorMapName = @"fantasy_map";
            filter.overlayName1 = @"overlay_softlight4";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"FANTASY_FILTER", nil);
            break;
        case QBGLFilterTypeFreedom:
            filter.colorMapName = @"freedom_map";
            filter.overlayName1 = @"overlay_softlight2";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"FREEDOM_FILTER", nil);
            break;
        case QBGLFilterTypeMild:
            filter.colorMapName = @"mild_map";
            filter.overlayName1 = @"overlay_softlight5";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"MILD_FILTER", nil);
            break;
        case QBGLFilterTypePrairie:
            filter.colorMapName = @"prairie_map";
            filter.overlayName1 = @"overlay_softlight5";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"PRAIRIE_FILTER", nil);
            break;
        case QBGLFilterTypeDeep:
            filter.colorMapName = @"deep_map";
            filter.overlayName1 = @"overlay_softlight2";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"DEEP_FILTER", nil);
            break;
        case QBGLFilterTypeGlow:
            filter.colorMapName = @"glow_map";
            filter.overlayName1 = @"overlay_softlight5";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"GLOW_FILTER", nil);
            break;
        case QBGLFilterTypeMist:
            filter.colorMapName = @"mist_map";
            filter.overlayName1 = @"overlay_softlight5";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"MIST_FILTER", nil);
            break;
        case QBGLFilterTypeVivid:
            filter.colorMapName = @"vivid_map";
            filter.overlayName1 = @"overlay_softlight1";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"VIVID_FILTER", nil);
            break;
        case QBGLFilterTypePinky:
            filter.colorMapName = @"pinky_map";
            filter.overlayName1 = @"overlay_softlight5";
            filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"PINK_FILTER", nil);
            break;
        case QBGLFilterTypeAdventure:
            filter.colorMapName = @"adventure_map";
            filter.overlayName1 = @"overlay_softlight2";
            filter.overlayName2 = @"overlay_softlight3";
            filter.localizedName = NSLocalizedString(@"ADVENTURE_FILTER", nil);
            break;
        default:
            filter.colorMapName = filter.overlayName1 = filter.overlayName2 = nil;
            filter.localizedName = NSLocalizedString(@"NORMAL_FILTER", nil);
            break;
    }
}

@end


