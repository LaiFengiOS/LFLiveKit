//
//  QBGLMagicFilterFactory.h
//  LFLiveKit
//
//  Created by Han Chang on 2018/4/24.
//  Copyright © 2018年 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "QBGLFilterTypes.h"

@class QBGLMagicFilterBase;

@interface QBGLMagicFilterFactory : NSObject

/**
 * For efficient filter switching, cache is default enabled.
 */
@property (nonatomic) BOOL cacheEnabled;

- (QBGLMagicFilterBase *)filterWithType:(QBGLFilterType)type;

- (void)clearCache;

@end
