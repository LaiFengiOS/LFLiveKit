//
//  QBGLMagicFilterFactory.m
//  LFLiveKit
//
//  Created by Han Chang on 2018/4/24.
//  Copyright © 2018年 admin. All rights reserved.
//

#import "QBGLMagicFilterFactory.h"
#import "QBGLMagicFilter.h"
#import "QBGLMagicFilterBase.h"

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

- (QBGLMagicFilterBase *)filterWithType:(QBGLFilterType)type animationView:(UIView *)animationView {
    QBGLMagicFilterBase *filter = _cacheEnabled ? _filterCache[@(type)] : nil;
    if (!filter) {
        filter = [self.class createFilterWithType:type animationView:animationView];
    }
    if (_cacheEnabled) {
        _filterCache[@(type)] = filter;
    }
    return filter;
}

- (void)clearCache {
    [_filterCache removeAllObjects];
}

- (void)preloadFiltersWithTextureCacheRef:(CVOpenGLESTextureCacheRef)textureCacheRef animationView:(UIView *)animationView {
    for (NSInteger type = QBGLFilterTypeFairytale; type <= QBGLFilterTypeWalden; type++) {
        QBGLMagicFilterBase *magicFilter = [self filterWithType:type animationView:animationView];
        magicFilter.type = type;
        magicFilter.textureCacheRef = textureCacheRef;
    }
}

- (void)updateInputOutputSizeForFilters:(CGSize)outputSize {
    [_filterCache enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        QBGLMagicFilterBase *filter = obj;
        filter.inputSize = filter.outputSize = outputSize;
    }];
}

- (void)updateViewPortSizeForFilters:(CGSize)viewPortSize {
    [_filterCache enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        QBGLMagicFilterBase *filter = obj;
        filter.viewPortSize = viewPortSize;
    }];
}

+ (QBGLMagicFilterBase *)createFilterWithType:(QBGLFilterType)type animationView:(UIView *)animationView {
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
//        case QBGLFilterTypeCrayon:
//            return [QBGLMagicFilter crayonFilterWithAnimationView:animationView];
//        case QBGLFilterTypeEarlybird:
//            return [QBGLMagicFilter earlyBirdFilter];
//        case QBGLFilterTypeEmerald:
//            return [QBGLMagicFilter emeraldFilter];
//        case QBGLFilterTypeEvergreen:
//            return [QBGLMagicFilter evergreenFilter];
        case QBGLFilterTypeFairytale:
            return [QBGLMagicFilter fairytaleFilterWithAnimationView:animationView];
//        case QBGLFilterTypeFreud:
//            return [QBGLMagicFilter freudFilter];
//        case QBGLFilterTypeHealthy:
//            return [QBGLMagicFilter healthyFilter];
//        case QBGLFilterTypeHudson:
//            return [QBGLMagicFilter hudsonFilter];
        case QBGLFilterTypeInkwell:
            return [QBGLMagicFilter inkwellFilterWithAnimationView:animationView];
//        case QBGLFilterTypeKevin:
//            return [QBGLMagicFilter kevinFilter];
//        case QBGLFilterTypeLatte:
//            return [QBGLMagicFilter latteFilter];
//        case QBGLFilterTypeLomo:
//            return [QBGLMagicFilter lomoFilter];
        case QBGLFilterTypeN1977:
            return [QBGLMagicFilter n1977FilterWithAnimationView:animationView];
//        case QBGLFilterTypeNashViller:
//            return [QBGLMagicFilter nashVillerFilter];
//        case QBGLFilterTypeNostalgia:
//            return [QBGLMagicFilter nostalgiaFilter];
        case QBGLFilterTypePixar:
            return [QBGLMagicFilter pixarFilterWithAnimationView:animationView];
//        case QBGLFilterTypeRise:
//            return [QBGLMagicFilter riseFilter];
        case QBGLFilterTypeRomance:
            return [QBGLMagicFilter romanceFilterWithAnimationView:animationView];
//        case QBGLFilterTypeSakura:
//            return [QBGLMagicFilter sakuraFilter];
//        case QBGLFilterTypeSierra:
//            return [QBGLMagicFilter sierraFilter];
//        case QBGLFilterTypeSketch:
//            return [QBGLMagicFilter sketchFilterWithAnimationView:animationView];
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
            return [QBGLMagicFilter waldenFilterWithAnimationView:animationView];
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
