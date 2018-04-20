//
//  QBGLColorMapFilter.h
//  Qubi
//
//  Created by Ken Sun on 2016/8/23.
//  Copyright © 2016年 Qubi. All rights reserved.
//

#import "QBGLYuvFilter.h"
#import "QBGLFilterTypes.h"

@interface QBGLColorMapFilter : QBGLYuvFilter

@property (copy, nonatomic, nullable) NSString *colorMapName;
@property (copy, nonatomic, nullable) NSString *overlayName1;
@property (copy, nonatomic, nullable) NSString *overlayName2;
@property (copy, nonatomic, nullable) NSString *localizedName;
@property (nonatomic) QBGLFilterType type;

- (nonnull instancetype)initWithColorMap:(nullable NSString *)colorMapName
                                overlay1:(nullable NSString *)overlayName1
                                overlay2:(nullable NSString *)overlayName2
                           localizedName:(nullable NSString *)localizedName;

@end
