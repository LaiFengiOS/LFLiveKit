//
//  QBGLFilterFactory.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/22.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QBGLFilterTypes.h"

@class QBGLFilter;
@class QBGLColorMapFilter;

@interface QBGLFilterFactory : NSObject

/**
 * For efficient filter switching, cache is default enabled.
 */
@property (nonatomic) BOOL cacheEnabled;

- (QBGLFilter *)filterWithType:(QBGLFilterType)type;

- (void)clearCache;

+ (void)refactorColorFilter:(QBGLColorMapFilter *)filter withType:(QBGLFilterType)type;

@end
