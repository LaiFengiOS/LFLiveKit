//
//  QBGLMagicFilterFactory.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/4/24.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QBGLFilterTypes.h"
#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>

@class QBGLMagicFilterBase;

@interface QBGLMagicFilterFactory : NSObject

/**
 * For efficient filter switching, cache is default enabled.
 */
@property (nonatomic) BOOL cacheEnabled;

- (QBGLMagicFilterBase *)filterWithType:(QBGLFilterType)type animationView:(UIView *)animationView;

- (void)clearCache;
- (void)preloadFiltersWithTextureCacheRef:(CVOpenGLESTextureCacheRef)textureCacheRef animationView:(UIView *)animationView;
- (void)updateInputOutputSizeForFilters:(CGSize)outputSize;
- (void)updateViewPortSizeForFilters:(CGSize)viewPortSize;

@end
