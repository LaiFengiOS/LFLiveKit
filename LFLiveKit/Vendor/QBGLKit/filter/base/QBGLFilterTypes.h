//
//  QBGLFilterTypes.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/22.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, QBGLFilterType) {
    // 17
    QBGLFilterTypeNone,
//    QBGLFilterTypeRich,
    QBGLFilterTypeWarm,
    QBGLFilterTypeSoft,
    QBGLFilterTypeRose,
    QBGLFilterTypeMorning,
    QBGLFilterTypeSunshine,
    QBGLFilterTypeSunset,
    QBGLFilterTypeCool,
    QBGLFilterTypeFreeze,
    QBGLFilterTypeOcean,
    QBGLFilterTypeDream,
    QBGLFilterTypeViolet,
    QBGLFilterTypeMellow,
//    QBGLFilterTypeBleak,
    QBGLFilterTypeMemory,
    QBGLFilterTypePure,
    QBGLFilterTypeCalm,
    QBGLFilterTypeAutumn,
    QBGLFilterTypeFantasy,
    QBGLFilterTypeFreedom,
    QBGLFilterTypeMild,
    QBGLFilterTypePrairie,
    QBGLFilterTypeDeep,
    QBGLFilterTypeGlow,
//    QBGLFilterTypeMemoir,
    QBGLFilterTypeMist,
    QBGLFilterTypeVivid,
//    QBGLFilterTypeChill,
    QBGLFilterTypePinky,
    QBGLFilterTypeAdventure,
    
    // magic camera
//    QBGLFilterTypeAmaro,
//    QBGLFilterTypeAntique,
//    QBGLFilterTypeBlackCat,
//    QBGLFilterTypeBrannan,
//    QBGLFilterTypeBrooklyn,
//    QBGLFilterTypeMagicCalm,
//    QBGLFilterTypeMagicCool,
    QBGLFilterTypeCrayon,
//    QBGLFilterTypeEarlybird,
//    QBGLFilterTypeEmerald,
//    QBGLFilterTypeEvergreen,
    QBGLFilterTypeFairytale,
//    QBGLFilterTypeFreud,
//    QBGLFilterTypeHealthy,
//    QBGLFilterTypeHudson,
    QBGLFilterTypeInkwell,
//    QBGLFilterTypeKevin,
//    QBGLFilterTypeLatte,
//    QBGLFilterTypeLomo,
    QBGLFilterTypeN1977,
//    QBGLFilterTypeNashViller,
//    QBGLFilterTypeNostalgia,
    QBGLFilterTypePixar,
//    QBGLFilterTypeRise,
    QBGLFilterTypeRomance,
//    QBGLFilterTypeSakura,
//    QBGLFilterTypeSierra,
    QBGLFilterTypeSketch,
//    QBGLFilterTypeSkinWhite,
//    QBGLFilterTypeSunrise,
//    QBGLFilterTypeMagicSunset,
//    QBGLFilterTypeSutro,
//    QBGLFilterTypeSweets,
//    QBGLFilterTypeTender,
//    QBGLFilterTypeToaster,
//    QBGLFilterTypeValencia,
    QBGLFilterTypeWalden,
//    QBGLFilterTypeMagicWarm,
//    QBGLFilterTypeWhiteCat,
//    QBGLFilterTypeXproll
};

@interface QBGLFilterTypes : NSObject

+ (NSArray<NSString*> *)filterNames;

+ (NSString *)filterNameAtIndex:(NSUInteger)index;

+ (NSString *)filterNameForType:(QBGLFilterType)type;

+ (QBGLFilterType)nextFilterForType:(QBGLFilterType)type;

+ (QBGLFilterType)previousFilterForType:(QBGLFilterType)type;

@end
