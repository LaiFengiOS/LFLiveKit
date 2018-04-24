//
//  QBGLMagicFilterFactory.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/4/24.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLMagicFilterFactory.h"
#import "QBGLMagicFilter.h"

@interface QBGLMagicFilterFactory ()

@property (strong, nonatomic) NSMutableDictionary<NSNumber*, QBGLMagicFilterBase*> *filterCache;

@end


@implementation QBGLMagicFilterFactory

- (instancetype)init {
    if (self = [super init]) {
        _cacheEnabled = YES;
        _filterCache = [NSMutableDictionary new];
    }
    return self;
}

- (QBGLMagicFilterBase *)filterWithType:(QBGLFilterType)type {
    QBGLMagicFilterBase *filter = _cacheEnabled ? _filterCache[@(type)] : nil;
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

+ (QBGLMagicFilterBase *)createFilterWithType:(QBGLFilterType)type {
    switch (type) {
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
        default:
            return nil;
    }
}

@end
